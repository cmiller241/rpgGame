extern vec2 center;
extern float radius;
extern vec4 color1;
extern vec4 color2;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    if (color1 == color2) {
        return color1;
    } else {    
        //Calculate the distance to the center
        number dist = distance(screen_coords, center);

        //Normalize the distance based on the radius
        number t = clamp(dist / radius, 0.0, 1.0);

        //Interpolate between the two colors based on the normalized distance 
        vec4 finalColor = mix(color1, color2, t);

        return finalColor;
    }
}