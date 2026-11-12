extern float time;
extern float windStrength;  // max horizontal UV shift at the very top of the quad
extern float windSpeed;
extern float phase;         // per-instance offset so trees don't sway in unison
extern float quadV0;        // top V coord of this sprite's quad within the atlas
extern float quadV1;        // bottom V coord of this sprite's quad within the atlas
extern float anchorV;       // 0-1, where the trunk actually meets the ground WITHIN
                             // the quad. NOT assumed to be 1.0 (bottom of quad) -
                             // sprites usually have transparent padding below the
                             // trunk, so this needs to be measured against the art.

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    // Where are we within this specific quad, 0 = top of sprite, 1 = bottom of quad
    float localV = clamp((texture_coords.y - quadV0) / (quadV1 - quadV0), 0.0, 1.0);
    // Distance from the true anchor point, not from the bottom of the quad
    float heightFactor = clamp((anchorV - localV) / anchorV, 0.0, 1.0); // 1 at canopy, 0 at anchor
    float bendAmount = heightFactor * heightFactor;  // ease so the base stays anchored

    float sway = sin(time * windSpeed + phase) * windStrength * bendAmount;

    // Shift the SAMPLE point rather than the pixel itself - this bends the
    // content within a fixed, unrotated quad instead of rotating the quad,
    // which is what avoids the nearest-neighbor stair-stepping.
    vec2 sampleCoords = texture_coords;
    sampleCoords.x -= sway;

    // Outside the quad's own horizontal bounds after shearing -> transparent,
    // not a stretched/wrapped sample from a neighboring sprite in the atlas.
    if (sampleCoords.x < 0.0 || sampleCoords.x > 1.0) {
        return vec4(0.0);
    }

    return Texel(texture, sampleCoords) * color;
}
