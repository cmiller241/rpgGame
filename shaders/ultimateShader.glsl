// ultimateShader.glsl  —  final compositing / lighting pass
//
// (terrainCommon.glsl is prepended to this file by src/shader.lua.)
//
// Drawn once per frame: canvas.offscreen (ground tiles) -> canvas.intermediate.
// For every screen pixel it:
//
//   1. Layers the object canvas (player, trees, crops) over the ground tiles.
//   2. For terrain pixels (anything not fully covered by an opaque object):
//        a. brightens higher ground slightly,
//        b. lights cliff faces by the sun's direction (faceLight),
//        c. darkens it if it's in shadow, either from a sprite (shadowCanvas.r)
//           or from terrain (ray-marched through the heightMap),
//        d. works out whether the player's lamp reaches it.
//      Opaque object pixels were already tinted for shadow on the CPU
//      (see lighting:objectTint), so they skip this.
//   3. Applies the time-of-day colour grade (LUT), except inside the lamp's
//      glow, where the ungraded colour shows through.

uniform Image objectCanvas;      // sprites; alpha 1 = fully covers the ground
uniform Image shadowCanvas;      // sprite shadows: R = sun shadow, G = lamp shadow

// Sun (see sun:getState)
uniform vec2  sunDir;            // ground-plane direction toward the sun
uniform float sunSlope;          // tan(altitude)
uniform float litLevel;          // brightness of sunlit pixels (ambient + direct sun)
uniform float shadowLevel;       // brightness of shadowed pixels (ambient only)
uniform float faceLight;         // brightness multiplier for cliff faces

// Lamp (point light carried by the player)
uniform vec3  lampPos;           // world x, y, height
uniform vec2  lampScreen;        // lamp position on screen (for sprite pixels)
uniform float lampRadius;

// Colour grading LUT: 32 blue slices of 32x32 (red across, green up), and
// several 32-row blocks stacked vertically for different times of day.
uniform Image lutImage;
uniform vec2  lutSize;           // (1024, 128)
uniform float lutRowA;           // first row of the "from" block
uniform float lutRowB;           // first row of the "to" block
uniform float lutMix;            // 0 = all A, 1 = all B

const float LAMP_STEP  = 2.0;
const int   LAMP_STEPS = 80;     // enough to cover lampRadius / LAMP_STEP

// Elevation brightening: +1 % per 6.4 px of height (a 5-tile cliff top is +25 %).
const float ELEVATION_BRIGHTEN = 1.0 / 640.0;

// Is there a clear line of sight from p to the lamp?
bool lampVisible(vec3 p) {
    vec3 toLamp = lampPos - p;
    float dist = length(toLamp.xy);
    if (dist < 1.0) return true;
    vec2 dir = toLamp.xy / dist;
    float slope = toLamp.z / dist;
    for (int i = 1; i <= LAMP_STEPS; i++) {
        float d = float(i) * LAMP_STEP;
        if (d >= dist) break;
        // +0.5 so a ray grazing along a flat top doesn't hit its own tile
        if (terrainHeightAt(p.xy + dir * d) > p.z + d * slope + 0.5) return false;
    }
    return true;
}

// Looks a colour up in one LUT block.
vec4 lutSample(vec3 idx, float blockRow) {
    vec2 uv = vec2((idx.b * 32.0 + idx.r + 0.5) / lutSize.x,
                   (blockRow + 31.0 - idx.g + 0.5) / lutSize.y);
    return Texel(lutImage, uv);
}

vec4 colourGrade(vec4 c) {
    vec3 idx = floor(clamp(c.rgb, 0.0, 1.0) * 31.0 + 0.5);  // 0..31 per channel
    vec4 graded = mix(lutSample(idx, lutRowA), lutSample(idx, lutRowB), lutMix);
    return vec4(graded.rgb, c.a);
}

vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screenPx) {
    vec4 objectPixel = Texel(objectCanvas, uv);
    vec4 pixel;
    bool inLamp;
    float lampDist;

    if (objectPixel.a < 1.0) {
        // ---- Terrain (possibly under a semi-transparent sprite edge) ----
        pixel = mix(Texel(texture, uv), objectPixel, objectPixel.a);

        bool isFace;
        vec3 p = surfacePoint(screenPx, isFace);

        pixel.rgb *= 1.0 + p.z * ELEVATION_BRIGHTEN;
        if (isFace) pixel.rgb *= faceLight;

        vec4 spriteShadow = Texel(shadowCanvas, uv);

        // How much direct sun is blocked here (0 = fully lit, 1 = fully shadowed).
        // Only worth computing while there is direct sun to block.
        float shade = 0.0;
        if (litLevel > shadowLevel) {
            shade = spriteShadow.r;
            if (shade < 1.0) shade = max(shade, terrainShadow(p, sunDir, sunSlope, isFace));
        }
        pixel.rgb *= mix(litLevel, shadowLevel, shade);

        // Only bother tracing toward the lamp inside its radius.
        lampDist = length(p.xy - lampPos.xy);
        inLamp = lampDist < lampRadius && spriteShadow.g == 0.0 && lampVisible(p);
    } else {
        // ---- Opaque sprite: already shadow-tinted on the CPU ----
        pixel = objectPixel;
        lampDist = distance(screenPx, lampScreen);
        inLamp = true;
    }

    vec4 graded = colourGrade(pixel);
    if (!inLamp) return graded;

    // Inside the lamp: fade from the true colour at the centre to the graded
    // colour at the edge of the radius.
    return mix(pixel, graded, clamp(lampDist / lampRadius, 0.0, 1.0));
}
