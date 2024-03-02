extern vec4 rect;

vec4 effect(vec4 color, Image texture, vec2 textureCoords, vec2 screenCoords) {
    // Calculate the gradient factor
    number gradient = 0.3 * (screenCoords.y - rect.y) / rect.w;

    // Create a color that goes from black at the bottom to transparent at the top
    vec4 gradientColor = vec4(0.0, 0.0, 0.0, gradient);

    // Apply the gradient color
    return gradientColor;
}