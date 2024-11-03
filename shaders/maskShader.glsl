extern vec4 maskColor; // RGBA color to use for the sprite's opaque areas

vec4 effect(vec4 color, Image texture, vec2 textureCoords, vec2 screenCoords) {
    vec4 pixelColor = Texel(texture, textureCoords);

    if (pixelColor.a > 0.0) {
        return vec4(maskColor.rgb * maskColor.a, pixelColor.a);
    } else {
        return pixelColor;
    }
}