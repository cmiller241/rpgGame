extern number brightness;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    // Sample the pixel from the texture
    vec4 pixel = Texel(texture, texture_coords);
    
    // Multiply each color channel by the brightness factor
    pixel.r *= brightness;
    pixel.g *= brightness;
    pixel.b *= brightness;
    
    // Clamp the values to the range [0, 1] to avoid overflow
    pixel.r = clamp(pixel.r, 0.0, 1.0);
    pixel.g = clamp(pixel.g, 0.0, 1.0);
    pixel.b = clamp(pixel.b, 0.0, 1.0);
    
    return pixel;
}
