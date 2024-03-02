extern number hueAdjust;
extern number time;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec2 displacement = vec2(sin(texture_coords.x * texture_coords.y * 10.0 + time) * 0.005, 0.0);
    vec4 pixel = Texel(texture, texture_coords + displacement/2.0);

    // RGB to HSV
    float maxC = max(pixel.r, max(pixel.g, pixel.b));
    float minC = min(pixel.r, min(pixel.g, pixel.b));
    float delta = maxC - minC;

    float hue = 0.0;
    if (delta != 0.0) {
        if (maxC == pixel.r) {
            hue = ((pixel.g - pixel.b) / delta);
        } else if (maxC == pixel.g) {
            hue = ((pixel.b - pixel.r) / delta) + 2.0;
        } else {
            hue = ((pixel.r - pixel.g) / delta) + 4.0;
        }
        hue = mod((hue * 60.0) + 360.0 + hueAdjust, 360.0);
    }
    float saturation = (maxC != 0.0) ? delta / maxC : 0.0;
    float value = maxC;

    // HSV to RGB
    float c = value * saturation;
    float x = c * (1.0 - abs(mod(hue / 60.0, 2.0) - 1.0));
    float m = value - c;

    vec4 hsv;
    if (0.0 <= hue && hue < 60.0) {
        hsv = vec4(c, x, 0.0, pixel.a);
    } else if (60.0 <= hue && hue < 120.0) {
        hsv = vec4(x, c, 0.0, pixel.a);
    } else if (120.0 <= hue && hue < 180.0) {
        hsv = vec4(0.0, c, x, pixel.a);
    } else if (180.0 <= hue && hue < 240.0) {
        hsv = vec4(0.0, x, c, pixel.a);
    } else if (240.0 <= hue && hue < 300.0) {
        hsv = vec4(x, 0.0, c, pixel.a);
    } else {
        hsv = vec4(c, 0.0, x, pixel.a);
    }
    hsv.rgb += m;

    return hsv * color;
}
