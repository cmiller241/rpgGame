// sparkleShader.glsl  —  glowing motes of light (see src/pagesparkles.lua)
//
// Each mote is a small square sprite drawn with additive blending after the
// lighting pass, so it glows the same by day or night instead of being
// shaded like ordinary sprites. The square becomes a round glow: a bright
// pixel-sized core and a soft halo fading to nothing at its edge.
//
// Motes on the far side of their orbit (`behind`) are hidden wherever a
// sprite covers the pixel (the Bible page itself), so they pass behind it.

uniform Image objectCanvas;   // this frame's sprites; alpha > 0.5 = a sprite is here
uniform vec2  screenSize;     // size of the game canvases
uniform bool  behind;         // true while drawing the motes behind their page

const float CORE = 0.25;      // radius of the solid core (fraction of the sprite)
const float HALO = 0.75;      // brightness of the halo next to the core

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screenPx) {
    float r = length(uv * 2.0 - 1.0);          // 0 at the centre, 1 at the edge
    if (r >= 1.0) discard;
    if (behind && Texel(objectCanvas, screenPx / screenSize).a > 0.5) discard;
    float halo = (1.0 - r) * HALO;
    float a = r < CORE ? 1.0 : halo;
    return vec4(color.rgb, color.a * a);       // drawn with the "add" blend mode
}
