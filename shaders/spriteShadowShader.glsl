// spriteShadowShader.glsl  —  shadows cast by sprites (trees, crops, player)
//
// (terrainCommon.glsl is prepended to this file by src/shader.lua.)
//
// Drawn by spriteShadow:flush() as a plain screen-space rectangle covering
// everywhere this sprite's shadow could land. Output goes to canvas.shadow:
//     R = in this sprite's sun shadow (value = opacity)
//     G = in this sprite's lamp shadow
// using 'lighten' blending, so overlapping shadows combine with max().
//
// HOW IT WORKS
// A sprite is treated as a flat cut-out ("billboard") standing upright on a
// horizontal BASE LINE through its feet, facing the camera, exactly as it's
// drawn. For each screen pixel:
//   1. Rebuild the 3D world point p of the terrain visible there (this works
//      for cliff faces too, so shadows climb up walls correctly).
//   2. Fire a ray from p toward the light. Where the ray crosses the base
//      line's vertical plane (world y = casterBase.y) we know exactly
//      (a) the x position along the sprite and (b) how high above the
//      feet the ray is at that point.
//   3. Those two numbers are a pixel position in the sprite. If that sprite
//      pixel is opaque, p is in shadow.
// Because the plane never rotates, the shadow always starts at the feet and
// stretches away from the light (it shears sideways as the sun moves east or
// west), never spreading out below the feet.
// No loops: one silhouette read for hard edges, nine for soft ones.

uniform Image casterImage;       // image (or canvas) holding the sprite
uniform vec2  casterImageSize;   // its size in px
uniform vec4  casterQuad;        // sprite's rectangle within the image: x, y, w, h (px)
uniform vec2  casterAnchor;      // px inside the quad where the sprite touches the ground
uniform vec3  casterBase;        // world x, y, height of that ground contact point
uniform float casterLift;        // px the sprite is raised off the ground (jumping)
uniform float casterOpacity;     // sun shadow strength for this sprite (0..1)
uniform float castLampShadow;    // 1 = also block the player's lamp

uniform float sunUp;
uniform vec2  sunDir;
uniform float sunSlope;
uniform vec3  lampPos;
uniform float lampRadius;

// 1 if sprite pixel `px` (relative to the quad) is opaque, else 0.
float silhouette(vec2 px) {
    if (px.x < 0.0 || px.y < 0.0 || px.x >= casterQuad.z || px.y >= casterQuad.w) return 0.0;
    vec2 texUV = (casterQuad.xy + floor(px) + 0.5) / casterImageSize;
    return step(0.5, Texel(casterImage, texUV).a);
}

// How much of the light the sprite blocks for the ray from p heading along
// `dir` (climbing `slope` px per px), 0..1, if it reaches the sprite before
// travelling `maxT`.
//
// `softness` is the light's apparent size. The silhouette is sampled over a
// circle whose radius grows with distance from the sprite (t * softness): sharp
// right at the feet, softer toward the far end. 0 = one sample, hard edge.
float hitsBillboard(vec3 p, vec2 dir, float slope, float maxT, float softness) {
    // A ray running parallel to the base line never crosses it.
    if (abs(dir.y) < 0.001) return 0.0;

    // Distance along the ray until it reaches the base line's plane.
    float t = (casterBase.y - p.y) / dir.y;
    if (t <= 0.0 || t >= maxT) return 0.0;      // plane is behind us / past the light

    float lateral = p.x + dir.x * t - casterBase.x;     // x offset from the feet along the base line
    float heightAbove = p.z + t * slope - casterBase.z - casterLift;

    vec2 px = casterAnchor + vec2(lateral, -heightAbove);

    float r = t * softness;                     // blur radius in sprite pixels
    if (r < 0.5) return silhouette(px);         // too close to blur: hard edge

    // Centre plus 8 points around a circle of radius r.
    float d = r * 0.7071;
    float sum = silhouette(px)
              + silhouette(px + vec2( r, 0.0)) + silhouette(px + vec2(-r, 0.0))
              + silhouette(px + vec2(0.0,  r)) + silhouette(px + vec2(0.0, -r))
              + silhouette(px + vec2( d,  d)) + silhouette(px + vec2(-d,  d))
              + silhouette(px + vec2( d, -d)) + silhouette(px + vec2(-d, -d));
    return sum / 9.0;
}

vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screenPx) {
    bool isFace;
    vec3 p = surfacePoint(screenPx, isFace);

    float sunShadow = 0.0;
    if (sunUp > 0.5) {
        sunShadow = hitsBillboard(p, sunDir, sunSlope, 1.0e6, sunSoftness) * casterOpacity;
    }

    float lampShadow = 0.0;
    if (castLampShadow > 0.5) {
        vec2 toLamp = lampPos.xy - p.xy;
        float dist = length(toLamp);
        if (dist > 0.5 && dist < lampRadius) {
            // The lamp is a small point light, so its shadows stay hard.
            lampShadow = hitsBillboard(p, toLamp / dist, (lampPos.z - p.z) / dist, dist, 0.0);
        }
    }

    // Premultiplied output for the 'lighten' blend.
    return vec4(sunShadow, lampShadow, 0.0, max(sunShadow, lampShadow));
}
