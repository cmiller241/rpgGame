extern Image lutImage;
extern number angle;
float normalizedAngle;
float oldLut;
float newLut;


vec4 effect(vec4 color, Image texture, vec2 textureCoords, vec2 screenCoords) {
    if (angle >= 0 && angle <=80) {
        normalizedAngle = angle / 80.0;
        newLut = 127.0 - 31.0;
        oldLut = 127.0 - 127.0;
    }
    if (angle >= 80 && angle <=100) {
        normalizedAngle = angle / 90.0;
        newLut = 127.0 - 127.0;
        oldLut = 127.0 - 127.0;
    }
    if (angle > 100 && angle <=180) {
        normalizedAngle = (angle - 100.0) / 80.0;
        newLut = 127.0 - 127.0;
        oldLut = 127.0 - 95.0;
    }
    if (angle > 180 && angle <=260) {
        normalizedAngle = (angle - 180.0) / 80.0;
        newLut = 127.0 - 95.0;
        oldLut = 127.0 - 64.0;
    }
    if (angle > 260 && angle <=280) {
        normalizedAngle = (angle - 180.0) / 90.0;
        newLut = 127.0 - 64.0;
        oldLut = 127.0 - 64.0;
    }    
    if (angle > 280 && angle <=360) {
        normalizedAngle = (angle - 280.0) / 80.0;
        newLut = 127.0 - 64.0;
        oldLut = 127.0 - 31.0;
    }

    //Sample the original image
    vec4 texColor = Texel(texture, textureCoords);

    // Normalize the angle to [0,1]
    //float normalizedAngle = angle / 360.0; 

    // Normalize the color
    vec3 normalizedColor = texColor.rgb * 31.0;

    // Calculate the LUT image coordinates
    vec2 lutCoords1;
    vec2 lutCoords2;

    normalizedColor.b = floor(normalizedColor.b);

    lutCoords1.x = (normalizedColor.b * 32.0 + normalizedColor.r) / 1023.0;
    lutCoords1.y = (newLut + 31.0 - normalizedColor.g + 0.5) / 127.0;

    lutCoords2.x = (normalizedColor.b * 32.0 + normalizedColor.r) / 1023.0;
    lutCoords2.y = (oldLut + 31.0 - normalizedColor.g + 0.5) / 127.0;

    
    // Sample the LUT image
    vec4 lutColor1 = Texel(lutImage, lutCoords1);
    vec4 lutColor2 = Texel(lutImage, lutCoords2);

    // Interpolate between lutColor1 and lutColor2 based on normalized angle
    vec4 outputColor = mix(lutColor1, lutColor2, normalizedAngle);

     // Return the color from the LUT image
    return outputColor;
}