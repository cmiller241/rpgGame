vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    // Sample the current pixel
    vec4 current_pixel = Texel(texture, texture_coords);
    
    // If the current pixel is opaque, return its color
    if (current_pixel.a > 0.0) {
        return current_pixel * color;
    }
    
    // Assume sprite is 64x64 (based on Bible page sprite size)
    vec2 pixel_size = vec2(1.0 / 640.0, 1.0 / 640.0);
    
    // Sample neighboring pixels (up, down, left, right)
    vec4 up_pixel = Texel(texture, texture_coords + vec2(0.0, -pixel_size.y));
    vec4 down_pixel = Texel(texture, texture_coords + vec2(0.0, pixel_size.y));
    vec4 left_pixel = Texel(texture, texture_coords + vec2(-pixel_size.x, 0.0));
    vec4 right_pixel = Texel(texture, texture_coords + vec2(pixel_size.x, 0.0));
    
    // If any neighboring pixel is opaque, draw white outline
    if (up_pixel.a > 0.0 || down_pixel.a > 0.0 || left_pixel.a > 0.0 || right_pixel.a > 0.0) {
        return vec4(1.0, 1.0, 1.0, 1.0);
    }
    
    // Otherwise, keep transparent
    return vec4(0.0, 0.0, 0.0, 0.0);
}