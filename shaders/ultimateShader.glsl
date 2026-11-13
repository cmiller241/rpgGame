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

uniform float time;               // seconds, for animating water
uniform Image waterMap;           // 1 texel per tile: water depth / 255 (see water.lua)

// Player standing in water: the part of him below the waterline is tinted.
uniform float playerWaterLine;    // screen y of the water surface at his position
uniform float playerWaterDepth;   // how deep the water is at his feet (px); 0 = dry

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
        if (solidAt(terrainAt(p.xy + dir * d), p.z + d * slope + 0.5)) return false;
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

// WATER (see water.lua): surface-map G holds the water depth. Water is
// drawn by tinting whatever is beneath it, more opaquely the deeper it is,
// plus a few slowly shifting sparkle pixels.
const vec3 WATER_SHALLOW = vec3(0.30, 0.62, 0.78);
const vec3 WATER_DEEP    = vec3(0.08, 0.26, 0.45);
const float WATER_FULL_DEPTH = 48.0;   // px at which water reaches its deepest colour

// Water tint over `under` for water `depth` px deep. Opacity fades in over
// the first 2 px (a thin film barely shows), then grows from 45% to 88% as
// the water gets deeper.
vec3 waterTint(vec3 under, float depth) {
    float t = clamp(depth / WATER_FULL_DEPTH, 0.0, 1.0);
    float opacity = mix(0.45, 0.88, t) * clamp(depth / 2.0, 0.0, 1.0);
    return mix(under, mix(WATER_SHALLOW, WATER_DEEP, t), opacity);
}

// PUDDLE SHAPES ("metaballs")
// Shallow water isn't drawn as whole squares. Each wet tile (from waterMap)
// adds a soft round blob centred on the tile, (1 - r^2)^2 out to
// BLOB_RADIUS; a point is water where the blobs add up to PUDDLE_THRESHOLD.
// With these values:
//   * a lone wet tile is a circle ~0.9 tiles across,
//   * two neighbours join into an oval (the join is nearly full width),
//   * a big patch is solid (four tiles meeting sum to 1.0) with rounded
//     outer corners,
//   * tiles touching only at a corner stay separate (they sum to ~0.54).
// Water is only ever drawn inside wet tiles' squares, so blobs can't spill
// onto dry ground.
const float PUDDLE_MAX_DEPTH = 12.0;  // px; deeper water fills its tiles completely
const float BLOB_RADIUS = 1.0;        // tiles
const float PUDDLE_THRESHOLD = 0.64;

float wetTile(vec2 tile) {
    if (tile.x < 0.0 || tile.y < 0.0 || tile.x >= mapTiles.x || tile.y >= mapTiles.y) return 0.0;
    return Texel(waterMap, (tile + 0.5) / mapTiles).r > 0.0 ? 1.0 : 0.0;
}

bool insidePuddle(vec2 world) {
    vec2 t = world / tileSize;          // position in tiles
    vec2 base = floor(t);
    float field = 0.0;
    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            vec2 tile = base + vec2(float(dx), float(dy));
            if (wetTile(tile) > 0.0) {
                float r = length(t - (tile + 0.5)) / BLOB_RADIUS;
                float k = max(0.0, 1.0 - r * r);
                field += k * k;
            }
        }
    }
    return field >= PUDDLE_THRESHOLD;
}

vec3 waterColour(vec3 under, float depth, vec3 p) {
    vec3 c = waterTint(under, depth);
    // Sparkles: a pattern over whole world pixels so they stay crisp.
    vec2 w = floor(p.xy);
    float s = sin(w.x * 0.37 + time * 1.3) * sin(w.y * 0.53 - time * 1.1)
            + 0.5 * sin((w.x + w.y) * 0.21 + time * 0.7);
    if (s > 1.25) c += vec3(0.22) * clamp(depth / 2.0, 0.0, 1.0);   // faint on thin films too
    return c;
}

// Lights one terrain pixel: water, elevation, cliff-face light and sun shadow.
// `surf` is its surface-map sample; `spriteSun` how much sprite shadow is on it.
// Returns the lit colour and the pixel's world point (p) for the lamp.
vec3 lightTerrain(vec3 rgb, vec4 surf, vec2 screenPx, float spriteSun, out vec3 p) {
    bool isFace;
    p = surfacePointFrom(surf, screenPx, isFace);

    float waterDepth = surf.g * heightRange;
    if (waterDepth > 0.01 && (waterDepth >= PUDDLE_MAX_DEPTH || insidePuddle(p.xy))) {
        rgb = waterColour(rgb, waterDepth, p);
    }

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

// The player's pixel `c` at screenPx: if it's below the waterline, tint it
// like water that deep, with a lighter line where the surface meets him.
// Then colour grade it like any sprite.
vec4 finishPlayer(vec4 c, vec2 screenPx) {
    if (playerWaterDepth > 0.0) {
        float below = screenPx.y - playerWaterLine;
        if (below > 0.0) {
            c.rgb = waterTint(c.rgb, min(below, playerWaterDepth) + 2.0);
            if (below < 1.0) c.rgb += vec3(0.18);
        }
    }
    return finishSprite(c, screenPx);
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
        result = isPlayer ? finishPlayer(objectPixel, screenPx) : finishSprite(objectPixel, screenPx);
    }

    // PIT FOCUS (the player is below ground level; see lighting.lua).
    bool revealed = false;
    if (focusAmount > 0.0) {
        bool aboveHim;
        if (isTerrain) {
            // Above his level? Walls below ground level count as part of the
            // pit (its back wall), so only walls above ground are "above".
            // Water counts by the ground under it, so water in his pit is in focus.
            vec4 s = Texel(surfaceMap, uv);
            float groundZ = p.z - s.g * heightRange;
            aboveHim = (s.r > 0.5) ? (p.z > 0.5) : (groundZ > focusLevel + 0.5);
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
                under = finishPlayer(xray, screenPx);
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
        vec4 ghost = finishPlayer(xray, screenPx);
        result.rgb = mix(result.rgb, ghost.rgb, ghostOpacity * xray.a);
    }
    return result;
}
