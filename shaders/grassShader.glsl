extern number time;
extern number base;
extern number poop;
extern number cameraY;
extern number yTile;
//27.0 is the sprite
vec4 position(mat4 transform_projection, vec4 vertex_position) {
    if (vertex_position.y < base) {
        float changeTime = time;
        float calculateDistance = abs(vertex_position.y - base);

        // Smoother swaying with a combination of sin and noise
        float frequency = 1.0; // Adjust this for swaying speed
        float amplitude = 0.1 + calculateDistance * 0.005;  // Adjust this for swaying intensity

        // Combine sine and cosine for a more natural movement
        float movement = sin(changeTime * frequency - (yTile) / 27.0) * amplitude * pow((yTile) / 27.0, 1.5); //200 is just a large number that affects amplitude
        float addMovement = 0.0;

        if (poop == -1.0) {
            addMovement = 10;
        }

        if (poop == 1.0) {
            addMovement = -10;
        }

        // Adding a small random variation based on the vertex position
        float randomness = 0.05 * (fract(sin((yTile) * 0.1 + changeTime) * 43758.5453) - 0.5);
        vertex_position.x += movement + randomness + addMovement;
    }
    return transform_projection * vertex_position;
}