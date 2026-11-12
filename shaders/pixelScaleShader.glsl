// pixelScaleShader.glsl  —  "sharp bilinear" upscaling for pixel art
//
// Used to draw the finished game frame (canvas.intermediate, linear filter)
// onto the window at any scale >= 1.
//
// Plain nearest-neighbour at a non-whole scale (e.g. 1.6x) makes some art
// pixels 2 screen pixels wide and some 1: an uneven, wobbly look. Plain
// linear filtering blurs everything. This does neither: each art pixel is
// drawn as a solid square, and only the single row/column of screen pixels
// where two art pixels meet is blended between them.
//
// At whole-number scales every screen pixel lands inside an art pixel's solid
// region, so the result is exactly the same as nearest-neighbour.

uniform vec2  texSize;   // size of the texture being drawn, in px
uniform float scale;     // how many screen px per texture px (>= 1)

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screenPx) {
    vec2 texel  = uv * texSize;
    vec2 base   = floor(texel);
    vec2 offset = fract(texel) - 0.5;         // -0.5 .. 0.5 across this art pixel

    // The middle part of each art pixel (all but the outer half screen pixel
    // on each side) snaps to the pixel's centre; the edges blend into the
    // neighbour over exactly one screen pixel.
    float solid = 0.5 - 0.5 / scale;
    vec2 f = (offset - clamp(offset, -solid, solid)) * scale + 0.5;

    return Texel(tex, (base + f) / texSize) * color;
}
