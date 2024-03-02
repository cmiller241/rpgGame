extern number time;
vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec2 displacement = vec2(sin(texture_coords.x * texture_coords.y * 10.0 + time) * 0.005, 0.0);
    vec4 pixel = Texel(texture, texture_coords + displacement);
    return pixel * color;
}