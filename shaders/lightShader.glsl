extern vec2 lightPosition;
extern number lightIntensity;
extern Image normalMap;

vec4 effect(vec4 color, Image texture, vec2 textureCoords, vec2 screenCoords) {
    // Get the color and normal from the texture and normal map
    vec4 pixelColor = Texel(texture, textureCoords);
    vec3 normal = Texel(normalMap, textureCoords).rgb;

    // Transform the normal from [0,1] to [-1,1]
    normal = normal * 2.0 - 1.0;

    // Calculate the light direction  
    vec2 lightDir = lightPosition - screenCoords;
    float distance = length(lightDir);

    // Normalize the light direction
    lightDir = lightDir / distance;

    // Calculate the diffuse light intensity
    float diffuse = max(dot(normal, vec3(lightDir, 0.0)), 0.0);

    // Attenuate the light based on distance
    diffuse = diffuse * (1.0 / (1.0 + (0.01 * distance * distance)));   

    // Apply the light to the color
    vec4 litColor = vec4(pixelColor.rgb * diffuse * lightIntensity, pixelColor.a);

    return litColor;
}