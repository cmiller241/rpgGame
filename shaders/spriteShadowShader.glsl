// spriteShadowShader.glsl  —  shadows cast by sprites (trees, crops, pages, player)
//
// (terrainCommon.glsl is prepended to this file by src/shader.lua.)
//
// spriteShadow:flush() draws one screen-space rectangle per caster, covering
// everywhere that caster's shadow could land. Casters on the same sprite sheet
// share a single draw call: each rectangle's vertices carry that caster's
// details as extra attributes, passed through to the pixel stage below.
//
// Output goes to canvas.shadow:
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
//      line's vertical plane (world y = base.y) we know exactly
//      (a) the x position along the sprite and (b) how high above the
//      feet the ray is at that point.
//   3. Those two numbers are a pixel position in the sprite. If that sprite
//      pixel is opaque, p is in shadow.
// Because the plane never rotates, the shadow always starts at the feet and
// stretches away from the light (it shears sideways as the sun moves east or
// west), never spreading out below the feet.
// No loops: one silhouette read for hard edges, nine for soft ones.

// Per-caster data, constant across each rectangle.
varying vec4 vQuad;          // sprite's rectangle within the image: x, y, w, h (px)
varying vec4 vAnchorLift;    // anchor x, anchor y (px in quad), lift (px), sun opacity
varying vec4 vBase;          // world x, y, height of the anchor; castLamp (0/1)
varying vec2 vSway;          // wind: px shift at the sprite's top, bend start (fraction down)

#ifdef VERTEX
attribute vec4 CasterQuad;
attribute vec4 CasterAnchorLift;
attribute vec4 CasterBase;
attribute vec2 CasterSway;

vec4 position(mat4 transform_projection, vec4 vertex_position) {
    vQuad = CasterQuad;
    vAnchorLift = CasterAnchorLift;
    vBase = CasterBase;
    vSway = CasterSway;
    return transform_projection * vertex_position;
}
#endif

#ifdef PIXEL
uniform Image casterImage;       // sprite sheet (or canvas) for this draw call
uniform vec2  casterImageSize;   // its size in px

uniform float sunUp;
uniform vec2  sunDir;
uniform float sunSlope;
uniform vec3  lampPos;
uniform float lampRadius;

// 1 if sprite pixel `px` (relative to the quad) is opaque, else 0.
// Applies the same wind bend as windSwayShader.glsl so the shadow sways
// with the canopy.
float silhouette(vec2 px) {
    float bend = clamp((vSway.y - px.y / vQuad.w) / vSway.y, 0.0, 1.0);
    px.x -= vSway.x * bend * bend;
    if (px.x < 0.0 || px.y < 0.0 || px.x >= vQuad.z || px.y >= vQuad.w) return 0.0;
    vec2 texUV = (vQuad.xy + floor(px) + 0.5) / casterImageSize;
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
    float t = (vBase.y - p.y) / dir.y;
    if (t <= 0.0 || t >= maxT) return 0.0;      // plane is behind us / past the light

    float lateral = p.x + dir.x * t - vBase.x;          // x offset from the feet along the base line
    float heightAbove = p.z + t * slope - vBase.z - vAnchorLift.z;

    vec2 px = vAnchorLift.xy + vec2(lateral, -heightAbove);

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
        sunShadow = hitsBillboard(p, sunDir, sunSlope, 1.0e6, sunSoftness) * vAnchorLift.w;
    }

    float lampShadow = 0.0;
    if (vBase.w > 0.5) {
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
#endif
