extern Image colorMapCanvas;
extern float shadowAngle;
extern float shadowSize;
extern float shadowOpacity;
extern float spriteWidth;
extern float spriteHeight;
extern float spriteBase;
extern float spriteLeftX;
extern float spriteTopY;
extern float divideBy;
extern vec2 canvasSize; 
extern float xstart;
extern float xend;
extern vec2 spotlight;   
extern float showSpotlight;           
float base = spriteTopY + spriteBase;
float baseX1 = spriteLeftX + xstart;
float baseX2 = spriteLeftX + xend; 
float baseScreenY = base / canvasSize.y;
float baseScreenX1 = baseX1 / canvasSize.x;
float baseScreenX2 = baseX2 / canvasSize.x; 
const float PI = 3.14159265359;
float rad = shadowAngle * PI / 180.0;
float yMovement = sin(rad) / canvasSize.y;                                              //Normalized y angle movement given angle (up or down check)
float canvasSizeY = 1.0 / canvasSize.y;
float spriteSizeY = 1.0 / spriteHeight;
float normalizedSpriteBase = spriteBase / spriteHeight;
float normalizedDivideBy = divideBy / spriteHeight;
vec2 normalizedSpotlight = spotlight / canvasSize;

vec2 spriteAngleMove = vec2(cos(rad) / spriteWidth, sin(rad) / spriteHeight);           //What way angle is moving (+x,+y)
vec2 canvasAngleMove = vec2(cos(rad) / canvasSize.x, sin(rad) / canvasSize.y); 

//float crossProduct2D(vec2 a, vec2 b) {
//    return a.x * b.y - a.y * b.x;
//}

//bool segmentsIntersect(vec2 p, vec2 p2, vec2 q, vec2 q2) {
//    vec2 r = p2 - p;
//    vec2 s = q2 - q;
//    float rxs = crossProduct2D(r, s);
//    vec2 qmp = q - p;
//    if (abs(rxs) < 0.0001) {
//        return false; // Lines are parallel or collinear
//    }
//    float t = crossProduct2D(qmp, s) / rxs;
//    float u = crossProduct2D(qmp, r) / rxs;
//    return (t >= 0.0 && t <= 1.0 && u >= 0.0 && u <= 1.0);
//}

vec4 effect(vec4 color, Image texture, vec2 textureCoords, vec2 screenCoords) {
    vec2 pos = textureCoords;
    //if (pos.y > normalizedSpriteBase) return vec4(0.0);                                 //Shadows cast by sun don't cast BELOW sprite (it'd happen during night)
    vec2 normalizedScreenCoords = screenCoords / canvasSize;                            //Current pixel on screen normalized for textureCoords
    vec4 colorMapPixel = Texel(colorMapCanvas, normalizedScreenCoords);                 //Get pixel from colorMapPixel at same coordinate
    //if (colorMapPixel.r == 1.0) {                                                       //If pixel is on a mountain face tile...
    //    float newY = normalizedScreenCoords.y + yMovement;                              //Is angle moving up or down
    //    bool isGoingDown = true;                                                        //Default isGoingDown to true
    //    if (newY > normalizedScreenCoords.y) {                                          //The shadow is moving downwards.
    //        for (int i = 1; i<= shadowSize; i++) {                                      //Follow shadow path to find occluder...
    //            if (colorMapPixel.r == 1.0) {                                           //If shadow is on wall face, go down...
    //                normalizedScreenCoords.y += canvasSizeY;                            //Go down by one pixel on canvas
    //                pos.y += spriteSizeY;                                               //Go down by one pixel on sprite texture
    //            } else {                                                                //Otherwise, follow angle. 
    //                if (isGoingDown == true) isGoingDown = false;
    //                normalizedScreenCoords += canvasAngleMove;
    //                pos += spriteAngleMove;
    //            }
    //            if (normalizedScreenCoords.y >= baseScreenY - 0.001 &&                  //If path hits sprite base...
    //                normalizedScreenCoords.y <= baseScreenY + 0.001 && 
    //                normalizedScreenCoords.x >= baseScreenX1 &&
    //                normalizedScreenCoords.x <= baseScreenX2) {
    //                pos.y -= i*normalizedDivideBy;                                      //Go up sprite from base by i to see if sprite pixel exists
    //                vec4 new_pixel = Texel(texture, pos);                           
    //                if (new_pixel.a != 0.0) {                                           //If it does, then draw shadow pixel
    //                    return vec4(0, 0, .1, shadowOpacity);
    //                }
    //            }   
    //            colorMapPixel = Texel(colorMapCanvas, normalizedScreenCoords);            //Get colorMapPixel after movement for next loop iteration
    //        }
    //    } 
    //} else {                                                                            //If the shadow isn't on a wall
        //if (segmentsIntersect(                                                         //Check if shadow intersects with sprite base
        //    normalizedScreenCoords,
        //    normalizedScreenCoords + shadowSize * canvasAngleMove,  
        //    vec2(baseScreenX1, baseScreenY),
        //    vec2(baseScreenX2, baseScreenY))) {
            for (int i = 0; i <= shadowSize; i++) {                                     //Why do I loop if I check collision the line before? Oh well FOR NOW. 
                normalizedScreenCoords += canvasAngleMove;
                pos += spriteAngleMove;
                colorMapPixel = Texel(colorMapCanvas, normalizedScreenCoords); 
                //if (colorMapPixel.b != faceHeight) return vec4(0.0); //If an occluder in way...
                if (normalizedScreenCoords.y >= baseScreenY - 0.003 &&
                    normalizedScreenCoords.y <= baseScreenY + 0.003 && 
                    normalizedScreenCoords.x >= baseScreenX1 &&
                    normalizedScreenCoords.x <= baseScreenX2) {                              
                    pos.y -= i*divideBy/spriteHeight;                                      //Check if distance above sprite base has content
                    vec4 new_pixel = Texel(texture, pos);                               //Get pixel above base
                    if (new_pixel.a != 0.0) {                                           //Does it have content...
                        return vec4(0.0, 0.0, 0.1, shadowOpacity); // red color
                    } else {
                        break;                                             //Still want to check spotlight shadows
                    }
                }   
            }
        //}
    //}

    if (showSpotlight == 1.0) {
//        //SPOTLIGHT SHADOWS
//        pos = textureCoords;
//        vec2 diff = spotlight - screenCoords;
//        float shadowRad = atan(diff.y, diff.x);                 //Angle from pixel to light source
//        vec2 spriteAngleMove = vec2(cos(shadowRad) / spriteWidth, sin(shadowRad) / spriteHeight);
//        vec2 canvasSpotlightAngleMove = vec2(cos(shadowRad) / canvasSize.x, sin(shadowRad) / canvasSize.y);  
//        normalizedScreenCoords = screenCoords / canvasSize;
//        for (int i = 0; i <= shadowSize; i++) {
//            normalizedScreenCoords += canvasSpotlightAngleMove;
//            pos += spriteAngleMove;
//            //colorMapPixel = Texel(colorMapCanvas, normalizedScreenCoords); 
//            //if (colorMapPixel.b != faceHeight) return vec4(0.0); //If an occluder in way...
//            if (normalizedScreenCoords.y >= baseScreenY - 0.003 &&
//                normalizedScreenCoords.y <= baseScreenY + 0.003 && 
//                normalizedScreenCoords.x >= baseScreenX1 &&
//                normalizedScreenCoords.x <= baseScreenX2) {
//                pos.y -= i/spriteHeight;
//                vec4 new_pixel = Texel(texture, pos);
//                if (new_pixel.a != 0.0) {
//                    return vec4(1.0, 0.0, 0.0, 1.0); // red color
//                } else {
//                    break;
//                }
//            }   
//        }
    }

    return vec4(0.0);
}