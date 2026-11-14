// dustShader.glsl  —  one puff of dust (see src/dust.lua)
//
// Each puff is a small rectangle (wider than tall, it hugs the ground). The
// shader turns it into a soft, ragged blob: denser in the middle, a lumpy
// edge that shifts as it ages, a grainy speckle per pixel, and stepped
// density levels so it stays pixel-art crisp. color.a carries the puff's
// overall opacity (fading out with age).
//
// It's drawn onto the sprite canvas semi-transparent, so the lighting pass
// lights it as the ground beneath it (shade, night, lamp).

uniform float seed;   // 0..1, different for every puff
uniform float age;    // 0 = just kicked up, 1 = gone

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screenPx) {
    vec2 p = uv * 2.0 - 1.0;                         // -1..1 across the puff
    float r = length(p);
    float angle = atan(p.y, p.x);
    // Lumpy outline: a couple of slow waves around the edge.
    float edge = 1.0 + 0.16 * sin(angle * 3.0 + seed * 6.28)
                     + 0.10 * sin(angle * 5.0 - seed * 4.0 + age * 3.0);
    float d = r / edge;
    if (d >= 1.0) discard;

    float density = 1.0 - d * d;                      // full in the middle, soft near the edge
    // Grainy speckle, fixed per screen pixel and puff.
    float grain = fract(sin(dot(floor(screenPx), vec2(12.9898, 78.233)) + seed * 17.0) * 43758.5453);
    density *= 0.8 + 0.45 * grain;
    density = floor(density * 3.0 + 0.5) / 3.0;      // a few crisp levels
    return vec4(color.rgb, color.a * clamp(density, 0.0, 1.0));
}
