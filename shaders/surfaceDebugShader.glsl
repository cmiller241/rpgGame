// surfaceDebugShader.glsl  —  visualises canvas.surface (press C in game)
//
//   red tint    = cliff face / pit wall
//   blue tint   = raised top
//   purple tint = pit floor
//   brightness  = how far from ground level (plain ground is left see-through)

uniform float heightRange;
uniform float maxTerrainHeight;

vec4 effect(vec4 color, Image surface, vec2 uv, vec2 screenPx) {
    vec4 s = Texel(surface, uv);
    float h = s.b * heightRange;
    bool isFace = s.r > 0.5;
    if (!isFace && abs(h) < 0.5) return vec4(0.0);    // plain ground: leave the scene visible
    float amount = clamp(abs(h) / max(maxTerrainHeight, 160.0), 0.0, 1.0);
    vec3 tint = isFace ? vec3(1.0, 0.35, 0.25)
              : (h > 0.0 ? vec3(0.3, 0.6, 1.0) : vec3(0.7, 0.3, 1.0));
    return vec4(tint * (0.25 + 0.75 * amount), 0.85);
}
