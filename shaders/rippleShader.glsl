// rippleShader.glsl  —  one ripple ring on the water (see src/splash.lua)
//
// Drawn on a rectangle twice as wide as it is tall (the water is seen from
// above at an angle, so a circle on it looks like a flat ellipse). Only a
// thin band at the edge is kept: the ring. It's solid pixels (pixel-art
// crisp, and lit like a sprite); it fades by dropping pixels in an ordered
// dither pattern rather than by going transparent.
//
// Each ripple is drawn as two halves so the player can stand inside it: the
// back half is sorted behind him, the front half in front of his legs.

uniform vec2  sizePx;      // the rectangle's size on screen (px)
uniform float thickness;   // ring width in px
uniform float fade;        // 1 = whole ring, 0 = gone
uniform float part;        // -1 = back (top) half only, 1 = front (bottom) half only, 0 = all

// 4x4 ordered (Bayer) dither threshold, 0..1, for a screen pixel.
float bayer2(vec2 a) { a = floor(a); return fract(dot(a, vec2(0.5, a.y * 0.75))); }
float bayer4(vec2 a) { return bayer2(0.5 * a) * 0.25 + bayer2(a); }

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screenPx) {
    vec2 p = uv * 2.0 - 1.0;
    float r = length(p);
    if (r > 1.0) discard;
    // Distance (px) in from the ellipse's edge, so the ring is the same
    // width all the way round even though the ellipse is flat.
    vec2 q = p * sizePx * 0.5;                    // px from the centre
    float inPx = r > 1.0e-4 ? (1.0 - r) * length(q) / r : 1.0e4;
    if (inPx > thickness) discard;
    if (part < 0.0 && p.y > 0.0) discard;
    if (part > 0.0 && p.y <= 0.0) discard;
    if (bayer4(screenPx) >= fade) discard;
    return color;
}
