// windSwayShader.glsl  —  bends a tree's canopy in the wind
//
// The sway amount is computed in Lua (tree.lua) and also given to the tree's
// shadow (spriteShadowShader.glsl), so the shadow sways in step with the
// canopy. Both use the same bend curve: none at the trunk's base, growing
// with the square of the height above it.

uniform float sway;     // horizontal shift at the very top of the sprite, in UV units of the atlas
uniform float quadV0;   // top V coord of this sprite's quad within the atlas
uniform float quadV1;   // bottom V coord of this sprite's quad within the atlas
uniform float anchorV;  // 0-1, where the trunk meets the ground WITHIN the quad (not
                        // assumed to be 1.0: sprites usually have transparent padding
                        // below the trunk, so this is measured against the art)

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    // Where are we within this specific quad: 0 = top of sprite, 1 = bottom of quad
    float localV = clamp((texture_coords.y - quadV0) / (quadV1 - quadV0), 0.0, 1.0);
    // 1 at the very top, 0 at the anchor (and below it)
    float heightFactor = clamp((anchorV - localV) / anchorV, 0.0, 1.0);
    float bendAmount = heightFactor * heightFactor;  // ease so the base stays anchored

    // Shift the SAMPLE point rather than the pixel itself: this bends the
    // content within a fixed, unrotated quad instead of rotating the quad,
    // which avoids nearest-neighbour stair-stepping.
    vec2 sampleCoords = texture_coords;
    sampleCoords.x -= sway * bendAmount;

    // Sheared off the side of the atlas -> transparent, not a wrapped sample.
    if (sampleCoords.x < 0.0 || sampleCoords.x > 1.0) {
        return vec4(0.0);
    }

    return Texel(texture, sampleCoords) * color;
}
