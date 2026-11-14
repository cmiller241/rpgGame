// treeHeightShader.glsl  —  how high each pixel of a tree is (see tree.lua)
//
// Draws the same tree, bent by the wind exactly as windSwayShader.glsl bends
// it, but instead of its colour it writes the HEIGHT (px above the world's
// ground level) of every solid pixel into canvas.spriteHeight:
//
//     height = the tree's ground height + how far up the sprite the pixel is
//
// i.e. a pixel 100 px up the canopy counts as being 100 px above the ground,
// like a cliff pixel 100 px up a mountain. The lighting pass uses it for fog
// (fog pools low, so trunks stand in it and canopies rise out of it).
//   R = height / heightRange, A = 1 where there's tree.

uniform float sway;
uniform float quadV0;
uniform float quadV1;
uniform float anchorV;
uniform float baseHeight;    // ground height (px) at the trunk's base
uniform float baseScreenY;   // screen y of the trunk's base
uniform float heightRange;   // terrain.heightRange

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    // The same bend as windSwayShader.glsl, so the heights match the art.
    float localV = clamp((texture_coords.y - quadV0) / (quadV1 - quadV0), 0.0, 1.0);
    float heightFactor = clamp((anchorV - localV) / anchorV, 0.0, 1.0);
    vec2 sampleCoords = texture_coords;
    sampleCoords.x -= sway * heightFactor * heightFactor;
    if (sampleCoords.x < 0.0 || sampleCoords.x > 1.0) discard;
    if (Texel(texture, sampleCoords).a < 0.5) discard;

    float h = baseHeight + max(0.0, baseScreenY - screen_coords.y);
    return vec4(h / heightRange, 0.0, 0.0, 1.0);
}
