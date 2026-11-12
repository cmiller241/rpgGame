// surfaceDebugShader.glsl  —  visualises canvas.surface (press C in game)
//
//   red tint  = cliff face        blue tint = flat top / ground
//   brightness = height (black = ground level, bright = tallest tile)

uniform float heightRange;
uniform float maxTerrainHeight;

vec4 effect(vec4 color, Image surface, vec2 uv, vec2 screenPx) {
    vec4 s = Texel(surface, uv);
    float h = s.b * heightRange / max(maxTerrainHeight, 1.0);
    bool isFace = s.r > 0.5;
    if (!isFace && h <= 0.0) return vec4(0.0);    // plain ground: leave the scene visible
    vec3 tint = isFace ? vec3(1.0, 0.35, 0.25) : vec3(0.3, 0.6, 1.0);
    return vec4(tint * (0.25 + 0.75 * h), 0.85);
}
