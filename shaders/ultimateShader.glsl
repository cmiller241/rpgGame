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
//   4. Pit focus: while the player is below ground level, makes higher terrain
//      that covers the pit partly see-through, and dims everything else above
//      his level.
//   5. Where terrain in front hides the player, blends in a faint "ghost" of
//      him (from xrayCanvas) so you can always see where you are.

uniform Image objectCanvas;      // sprites; alpha 1 = fully covers the ground
uniform Image shadowCanvas;      // sprite shadows: R = sun shadow, G = lamp shadow
uniform Image xrayCanvas;        // the player alone, never hidden (see canvas.lua)
uniform float ghostOpacity;      // how strongly his hidden parts show through (0 = off)

// Pit focus (see lighting.lua): while the player is below ground level, the
// tiles at/below his level are also rendered on their own (focusCanvas +
// focusSurfaceMap). Higher terrain covering that layer becomes partly
// see-through; everything else above his level is dimmed.
uniform Image focusCanvas;        // tile art of the pit layer
uniform Image focusSurfaceMap;    // its terrain shape; alpha 0 where the layer is empty
uniform float focusAmount;        // 0 = off, 1 = fully on (eases in/out)
uniform float focusLevel;         // the player's ground height (negative, px)
uniform float focusRevealOpacity; // how much of the pit shows through higher ground
uniform float focusPlayerOpacity; // how much of the player shows through it
uniform float focusDim;           // how much darker/greyer things above him get

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

// Elevation brightening: +1 % per 6.4 px of height (a 5-tile cliff top is
// +25 %, a 5-tile pit floor -25 %). Never below MIN_ELEVATION_LIGHT.
const float ELEVATION_BRIGHTEN = 1.0 / 640.0;
const float MIN_ELEVATION_LIGHT = 0.6;

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

// Lights one terrain pixel: elevation, cliff-face light and sun shadow.
// `surf` is its surface-map sample; `spriteSun` how much sprite shadow is on it.
// Returns the lit colour and the pixel's world point (p) for the lamp.
vec3 lightTerrain(vec3 rgb, vec4 surf, vec2 screenPx, float spriteSun, out vec3 p) {
    bool isFace;
    p = surfacePointFrom(surf, screenPx, isFace);

    rgb *= max(MIN_ELEVATION_LIGHT, 1.0 + p.z * ELEVATION_BRIGHTEN);
    if (isFace) rgb *= faceLight;

    // How much direct sun is blocked here (0 = fully lit, 1 = fully shadowed).
    // Only worth computing while there is direct sun to block.
    float shade = 0.0;
    if (litLevel > shadowLevel) {
        shade = spriteSun;
        if (shade < 1.0) shade = max(shade, terrainShadow(p, sunDir, sunSlope, isFace));
    }
    return rgb * mix(litLevel, shadowLevel, shade);
}

// Colour grade a lit terrain pixel, letting the lamp's glow through if the
// lamp can reach world point p.
vec4 finishTerrain(vec4 pixel, vec3 p, bool lampBlockedBySprite) {
    vec4 graded = colourGrade(pixel);
    float lampDist = length(p.xy - lampPos.xy);
    // Only bother tracing toward the lamp inside its radius.
    if (lampDist < lampRadius && !lampBlockedBySprite && lampVisible(p)) {
        // Fade from the true colour at the lamp to the graded colour at its edge.
        return mix(pixel, graded, clamp(lampDist / lampRadius, 0.0, 1.0));
    }
    return graded;
}

// Colour grade a sprite pixel (already shadow-tinted on the CPU). Sprites near
// the player are always in his lamp's glow.
vec4 finishSprite(vec4 pixel, vec2 screenPx) {
    float lampDist = distance(screenPx, lampScreen);
    return mix(pixel, colourGrade(pixel), clamp(lampDist / lampRadius, 0.0, 1.0));
}

// Pit focus: darker and a little greyer, by `k` (0..1).
vec3 dimmed(vec3 c, float k) {
    float grey = dot(c, vec3(0.299, 0.587, 0.114));
    return mix(c, vec3(grey), 0.5 * k) * (1.0 - k);
}

vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screenPx) {
    vec4 objectPixel = Texel(objectCanvas, uv);
    vec4 xray = Texel(xrayCanvas, uv);
    bool isPlayer = xray.a > 0.5 && objectPixel.a > 0.5;   // his visible pixels
    vec4 result;
    vec3 p = vec3(0.0);
    bool isTerrain = objectPixel.a < 1.0;

    if (isTerrain) {
        // ---- Terrain (possibly under a semi-transparent sprite edge) ----
        vec4 pixel = mix(Texel(texture, uv), objectPixel, objectPixel.a);
        vec4 spriteShadow = Texel(shadowCanvas, uv);
        pixel.rgb = lightTerrain(pixel.rgb, Texel(surfaceMap, uv), screenPx, spriteShadow.r, p);
        result = finishTerrain(pixel, p, spriteShadow.g > 0.0);
    } else {
        // ---- Opaque sprite ----
        result = finishSprite(objectPixel, screenPx);
    }

    // PIT FOCUS (the player is below ground level; see lighting.lua).
    bool revealed = false;
    if (focusAmount > 0.0) {
        bool aboveHim;
        if (isTerrain) {
            // Above his level? Walls below ground level count as part of the
            // pit (its back wall), so only walls above ground are "above".
            bool isFace = Texel(surfaceMap, uv).r > 0.5;
            aboveHim = isFace ? (p.z > 0.5) : (p.z > focusLevel + 0.5);
        } else {
            aboveHim = !isPlayer;           // trees, crops, pages up on the ground
        }

        vec4 focusSurf = Texel(focusSurfaceMap, uv);
        if (isTerrain && aboveHim && focusSurf.a > 0.5) {
            // Higher ground covers part of the pit here: show the pit
            // (lit as itself) and the player in it through the higher ground.
            // The player himself shows through more strongly than the pit
            // floor, so he stays clearly in focus.
            vec3 fp;
            vec4 under = Texel(focusCanvas, uv);
            under.rgb = lightTerrain(under.rgb, focusSurf, screenPx, 0.0, fp);
            under = finishTerrain(under, fp, false);
            float opacity = focusRevealOpacity;
            if (xray.a > 0.5) {
                under = finishSprite(xray, screenPx);
                opacity = focusPlayerOpacity;
            }
            result.rgb = mix(result.rgb, under.rgb, opacity * focusAmount);
            revealed = true;
        } else if (aboveHim) {
            result.rgb = dimmed(result.rgb, focusDim * focusAmount);
        }
    }

    // GHOST: the player's sprite is here on the x-ray canvas, but the
    // sprite canvas was cleared here because terrain in front of him covers
    // this spot. Blend in his silhouette, coloured the way a visible sprite
    // pixel here would be. (Skipped where pit focus already reveals him.)
    if (!revealed && ghostOpacity > 0.0 && xray.a > 0.5 && objectPixel.a < 0.5) {
        vec4 ghost = finishSprite(xray, screenPx);
        result.rgb = mix(result.rgb, ghost.rgb, ghostOpacity * xray.a);
    }
    return result;
}
