// terrainCommon.glsl
//
// Shared helpers for any shader that needs the 3D shape of the world.
// src/shader.lua PREPENDS this file to ultimateShader.glsl and
// spriteShadowShader.glsl, so line numbers in compile errors for those
// shaders are offset by the length of this file.
//
// See src/terrain.lua for the full explanation of the coordinate system,
// the heightMap and the surface map. In short:
//
//   world point = (worldX, worldY, height)
//   screen      = (worldX - cameraX, worldY - height - cameraY)
//
// Uniforms are filled in by terrain:sendUniforms().

uniform Image surfaceMap;        // screen-space: R = is cliff face, B = height / heightRange
uniform Image heightMap;         // world-space, 1 texel per tile, height + heightBias packed in R (hi) + G (lo)
uniform float heightBias;        // added before packing so pits (negative heights) fit
uniform vec2  mapTiles;          // map size in tiles (cols, rows)
uniform float tileSize;          // 32
uniform float heightRange;       // multiply surfaceMap.b by this to get pixels
uniform float maxTerrainHeight;  // tallest tile on the map (px); rays above it can stop
uniform vec2  camera;            // world position of the screen's top-left pixel
uniform vec2  screenSize;        // size of the game canvases (window.width/height)
uniform float sunSoftness;       // apparent size of the sun (see sun.softness); 0 = razor-sharp shadows

// Sun ray-march settings. Keep in sync with terrain.sunStep / sunSteps.
const float SUN_STEP  = 3.0;     // px per step
const int   SUN_STEPS = 160;     // => shadows up to 480 px long

// Height in px of the tile under a world-space point (negative in a pit).
// Off-map = 0.
float terrainHeightAt(vec2 world) {
    vec2 tile = floor(world / tileSize);
    if (tile.x < 0.0 || tile.y < 0.0 || tile.x >= mapTiles.x || tile.y >= mapTiles.y) {
        return 0.0;
    }
    vec4 t = Texel(heightMap, (tile + 0.5) / mapTiles);
    return floor(t.r * 255.0 + 0.5) * 256.0 + floor(t.g * 255.0 + 0.5) - heightBias;
}

// Turns a surface-map sample `s` for screen pixel `screenPx` into the
// world-space point of the terrain there. `isFace` reports whether it's on a
// vertical wall. (Takes the sample so it works for any surface map, e.g. the
// pit focus layer's.)
vec3 surfacePointFrom(vec4 s, vec2 screenPx, out bool isFace) {
    float h = s.b * heightRange;
    isFace = s.r > 0.5;
    vec3 p = vec3(screenPx.x + camera.x, screenPx.y + camera.y + h, h);
    // A face pixel sits exactly on the tile boundary. Nudge it half a pixel
    // south (out of the wall) so the height lookups below don't land inside
    // its own cliff and shadow the wall with itself.
    if (isFace) p.y += 0.5;
    return p;
}

// The world-space point of the terrain visible at a screen pixel (main view).
vec3 surfacePoint(vec2 screenPx, out bool isFace) {
    return surfacePointFrom(Texel(surfaceMap, screenPx / screenSize), screenPx, isFace);
}

// How much of the sun terrain blocks for world point p: 0 = fully lit,
// 1 = fully shadowed, in between = soft edge (penumbra).
//
// Walks from p toward the sun across the ground plane; the ray climbs
// `slope` px for every px travelled. A tile taller than the ray blocks it.
// That alone makes taller cliffs cast longer shadows and low suns cast longer
// shadows, but gives a hard yes/no edge. Two things soften it:
//
//   * SIDE TO SIDE: the sun is a disc, not a point. We fire 4 rays fanned
//     across its width (`sunSoftness` wide) and average them, so a
//     shadow's side edges fade over a width that grows with distance.
//   * FAR END: each ray also tracks how narrowly it cleared (or missed)
//     the terrain, measured as an angle, and fades over the same
//     `sunSoftness` range instead of switching at exactly 0.
//
// Both effects grow with distance from the occluder, so a shadow is crisp
// where it meets the cliff and blurrier further away, like a real shadow.
float terrainShadow(vec3 p, vec2 dir, float slope, bool isFace) {
    if (p.z >= maxTerrainHeight) return 0.0;                // nothing can be above us
    float maxDist = (maxTerrainHeight - p.z) / slope;       // past here the ray clears everything

    // Sideways direction, scaled so `spread` values are fractions of the sun's width.
    vec2 side = vec2(dir.y, -dir.x) * sunSoftness;
    vec2 dirA = dir - side * 0.75;
    vec2 dirB = dir - side * 0.25;
    vec2 dirC = dir + side * 0.25;
    vec2 dirD = dir + side * 0.75;

    vec4 lit = vec4(1.0);  // how lit each of the 4 rays is so far (min along the ray)
    float invSoft = 0.5 / max(sunSoftness, 1.0e-4);

    for (int i = 1; i <= SUN_STEPS; i++) {
        float d = float(i) * SUN_STEP;
        if (d > maxDist) break;
        float rayH = p.z + d * slope;

        vec2 qA = p.xy + dirA * d;
        vec2 qB = p.xy + dirB * d;
        vec2 qC = p.xy + dirC * d;
        vec2 qD = p.xy + dirD * d;
        if (isFace) {
            // Rays from a wall must not bend back into the wall itself.
            qA.y = max(qA.y, p.y); qB.y = max(qB.y, p.y);
            qC.y = max(qC.y, p.y); qD.y = max(qD.y, p.y);
        }
        vec4 h = vec4(terrainHeightAt(qA), terrainHeightAt(qB),
                      terrainHeightAt(qC), terrainHeightAt(qD));

        // Clearance angle (rayH - h) / d mapped onto the sun's size:
        // -sunSoftness -> 0 (fully blocked), +sunSoftness -> 1 (fully clear).
        vec4 v = clamp(0.5 + (rayH - h) / d * invSoft, 0.0, 1.0);
        lit = min(lit, v);

        if (max(max(lit.x, lit.y), max(lit.z, lit.w)) <= 0.0) return 1.0;  // all four fully blocked
    }
    return 1.0 - dot(lit, vec4(0.25));
}
