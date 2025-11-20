extern float angle;
vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    // Sample the current pixel
    vec4 current_pixel = Texel(texture, texture_coords);
   
    // Constants
    const float baseLine = 80.0; // Pixels from top of sprite to where base of sprite is. 
    const float spriteHeight = 112.0; // Height of the sprite in pixels
    const float spriteWidth = 112.0; // Width of the sprite in pixels
    const float sheetHeight = 112.0; // Total height of the spritesheet in pixels
    const float sheetWidth = 960.0; // Total width of the spritesheet in pixels
    //const float angle = 130.0;
    const float PI = 3.14159265359;
    float rad = angle * PI / 180.0;
    vec2 spriteAngleMove = vec2(cos(rad) / spriteWidth, sin(rad) / spriteHeight); // Movement per pixel in sprite space
    const float shadowSize = 32.0; // Max shadow distance in pixels
    const float stepMove = 1.0; // Step size in pixels
    const float divideBy = 2.0; // From main.lua, adjust as needed
   
    // Calculate UV dimensions of one sprite in the spritesheet
    const float spriteUVHeight = spriteHeight / sheetHeight; // e.g., 32/640 = 0.05
    const float spriteUVWidth = spriteWidth / sheetWidth; // e.g., 32/320 = 0.1
   
    // If the current pixel is opaque, color it based on baseLine
    if (current_pixel.a > 0.0) {
        return vec4(0.0, 0.0, 0.0, 0.0);
    }
   
    // For transparent pixels, check for shadow
    // Convert texture_coords to sprite-local pixel coordinates
    float localUVX = fract(texture_coords.x / spriteUVWidth); // 0 to 1 within sprite
    float localUVY = fract(texture_coords.y / spriteUVHeight); // 0 to 1 within sprite
    vec2 localPixelPos = vec2(localUVX * spriteWidth, localUVY * spriteHeight); // 0 to 32 in x and y
   
    // Convert spriteAngleMove to UV space for texture sampling
    vec2 spriteAngleMoveUV = spriteAngleMove * vec2(spriteWidth / sheetWidth, spriteHeight / sheetHeight);
   
    // Loop to trace along the shadow angle
    vec2 pos = texture_coords; // Start at current UV coords
    for (int i = 0; i <= int(shadowSize); i += int(stepMove)) {
        pos += spriteAngleMoveUV; // Step in UV space
        float posLocalPixelY = fract(pos.y / spriteUVHeight) * spriteHeight; // Local y in pixels
       
        // Check if we've hit the baseLine (within 1 pixel tolerance)
        float tolerance = 1.0; // Pixel tolerance
        if (posLocalPixelY >= baseLine - tolerance && posLocalPixelY <= baseLine + tolerance) {
            // Sample upward by i * divideBy pixels
            vec2 samplePos = pos;
            samplePos.y -= float(i) * divideBy / sheetHeight; // Adjust y in UV space
            vec4 new_pixel = Texel(texture, samplePos);
           
            // If the pixel above baseLine is opaque, we're in shadow
            if (new_pixel.a > 0.0) {
                return vec4(0.0, 0.0, 0.0, 1.0); // Semi-transparent black shadow
            }
            break; // Stop after hitting baseLine
        }
    }
   
    // Otherwise, keep transparent
    return vec4(0.0, 0.0, 0.0, 0.0);
}