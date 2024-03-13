//extern float angle;
extern vec2 lightPosition;
extern Image objectCanvas;
extern float spriteLeftX;
extern float spriteTopY;
extern float spriteWidth;
extern float spriteHeight;
extern float spriteBase;
extern float xstart;
extern float xend;
extern float shadowSize;
extern float divideBy;
extern float opacity;
uniform vec2 canvasSize; 
float base = spriteTopY + spriteBase; //base plus top of sprite 80
float baseX1 = spriteLeftX + xstart;
float baseX2 = spriteLeftX + xend; 
const float PI = 3.14159265359;
float baseScreenY = base / canvasSize.y;
float baseScreenX1 = baseX1 / canvasSize.x;
float baseScreenX2 = baseX2 / canvasSize.x; 

float crossProduct2D(vec2 a, vec2 b) {
    return a.x * b.y - a.y * b.x;
}

bool segmentsIntersect(vec2 p, vec2 p2, vec2 q, vec2 q2) {
    vec2 r = p2 - p;
    vec2 s = q2 - q;
    float rxs = crossProduct2D(r, s);
    vec2 qmp = q - p;
    if (abs(rxs) < 0.0001) {
        return false; // Lines are parallel or collinear
    }
    float t = crossProduct2D(qmp, s) / rxs;
    float u = crossProduct2D(qmp, r) / rxs;
    return (t >= 0.0 && t <= 1.0 && u >= 0.0 && u <= 1.0);
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 pixel = Texel(texture, texture_coords);
    //if (pixel.a != 1.0) {
        vec2 pos = texture_coords;
        vec2 diff = lightPosition - screen_coords;
        float rad = atan(diff.y, diff.x);                 //Angle from pixel to light source
        vec2 spriteAngleMove = vec2(cos(rad) / spriteWidth, sin(rad) / spriteHeight);
        vec2 canvasAngleMove = vec2(cos(rad) / canvasSize.x, sin(rad) / canvasSize.y);   
        vec2 normalizedScreenCoords = screen_coords / canvasSize;
        float dist = distance(lightPosition, screen_coords);
        if (dist > 200) return vec4(0.0);       //If the pixel is too far away from light source, don't bother. 
        float theSize = shadowSize;
        if (dist < shadowSize) theSize = dist-2; 
        vec4 colorMapPixel = Texel(objectCanvas,normalizedScreenCoords);
        if (colorMapPixel.r == 1.0) {
        //    float faceHeight = colorMapPixel.b;
        //    float newY = normalizedScreenCoords.y + sin(rad) / canvasSize.y;
        //    bool isGoingDown = true;
        //    if (newY > normalizedScreenCoords.y) {
        //        for (int i = 1; i<= shadowSize; i++) {
        //            if (colorMapPixel.r == 1.0) {
        //                normalizedScreenCoords.y += 1.0 / canvasSize.y;
        //                pos.y += 1.0 / spriteHeight;
        //            } else {
        //                if (isGoingDown == true) isGoingDown = false;
        //                normalizedScreenCoords += canvasAngleMove;
        //                pos += spriteAngleMove;
        //            }
        //            colorMapPixel = Texel(objectCanvas, normalizedScreenCoords);
        //            if (normalizedScreenCoords.y >= baseScreenY - 0.001 &&
        //                normalizedScreenCoords.y <= baseScreenY + 0.001 && 
        //                normalizedScreenCoords.x >= baseScreenX1 &&
        //                normalizedScreenCoords.x <= baseScreenX2) {
        //                pos.y -= i*divideBy/spriteHeight;
        //                vec4 new_pixel = Texel(texture, pos);
        //                if (new_pixel.a != 0.0) {
        //                    return vec4(0, 0, .1, opacity);
        //                }
        //            }                
        //        }
        //    }
            return vec4(0.0);
        } else {
            if (!segmentsIntersect(
                normalizedScreenCoords,
                normalizedScreenCoords + shadowSize * canvasAngleMove,
                vec2(baseScreenX1, baseScreenY),
                vec2(baseScreenX2, baseScreenY)
            )) return vec4(0.0); //If the shadow doesn't intersect the base, don't draw anything
            float faceHeight = colorMapPixel.b;
            for (int i = -1; i <= theSize; i++) {
                normalizedScreenCoords += canvasAngleMove;
                pos += spriteAngleMove;
                colorMapPixel = Texel(objectCanvas, normalizedScreenCoords); //shadow_coords);
                if (colorMapPixel.b != faceHeight) return vec4(0.0); //If an occluder in way...
                if (normalizedScreenCoords.y >= baseScreenY - 0.003 &&
                    normalizedScreenCoords.y <= baseScreenY + 0.003 && 
                    normalizedScreenCoords.x >= baseScreenX1 &&
                    normalizedScreenCoords.x <= baseScreenX2) {
                    pos.y -= i*divideBy/spriteHeight;
                    vec4 new_pixel = Texel(texture, pos);
                    if (new_pixel.a != 0.0) {
                        return vec4(0.0, 0.0, 0.1, opacity); // red color
                    } else {
                        return vec4(0.0);
                        //return pixel;   //Does weird mirror stuff if you don't add this :-)
                    }
                }   
            }
        }
    //}
    return vec4(0.0); //We're only drawing the shadow
    //return pixel; 
}