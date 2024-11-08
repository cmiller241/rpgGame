extern float angle;
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
//vec2 canvasSize = vec2(640.0, 360.0);
float base = spriteTopY + spriteBase; //base plus top of sprite 80
float baseX1 = spriteLeftX + xstart;
float baseX2 = spriteLeftX + xend; 
const float PI = 3.14159265359;
float rad = angle * PI / 180.0;
float sinRad = sin(rad);
float cosRad = cos(rad);
bool isMovingUpward = sinRad > 0.0;
bool isMovingLeft = cosRad < 0.0;
vec2 spriteAngleMove = vec2(cos(rad) / spriteWidth, sin(rad) / spriteHeight);
vec2 canvasAngleMove = vec2(cos(rad) / love_ScreenSize.x, sin(rad) / love_ScreenSize.y);   
float baseScreenY = base / love_ScreenSize.y;
float baseScreenX1 = baseX1 / love_ScreenSize.x;
float baseScreenX2 = baseX2 / love_ScreenSize.x; 

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
        vec2 normalizedScreenCoords = screen_coords / love_ScreenSize.xy;
        vec4 colorMapPixel = Texel(objectCanvas,normalizedScreenCoords);
        if (colorMapPixel.r == 1.0) {
            float faceHeight = colorMapPixel.b;
            float newY = normalizedScreenCoords.y + sin(rad) / love_ScreenSize.y;
            bool isGoingDown = true;
            if (newY > normalizedScreenCoords.y) {
                for (int i = 1; i<= shadowSize; i++) {
                    if (colorMapPixel.r == 1.0) {
                        normalizedScreenCoords.y += 1.0 / love_ScreenSize.y;
                        pos.y += 1.0 / spriteHeight;
                    } else {
                        if (isGoingDown == true) isGoingDown = false;
                        normalizedScreenCoords += canvasAngleMove;
                        pos += spriteAngleMove;
                    }
                    colorMapPixel = Texel(objectCanvas, normalizedScreenCoords);
                    if (normalizedScreenCoords.y >= baseScreenY - 0.001 &&
                        normalizedScreenCoords.y <= baseScreenY + 0.001 && 
                        normalizedScreenCoords.x >= baseScreenX1 &&
                        normalizedScreenCoords.x <= baseScreenX2) {
                        pos.y -= i*divideBy/spriteHeight;
                        vec4 new_pixel = Texel(texture, pos);
                        if (new_pixel.a != 0.0) {
                            return vec4(0, 0, 0, opacity);
                        }
                    }                
                }
            }
        } else {
            if (!segmentsIntersect(
                normalizedScreenCoords,
                normalizedScreenCoords + shadowSize * canvasAngleMove,
                vec2(baseScreenX1, baseScreenY),
                vec2(baseScreenX2, baseScreenY)
            )) return vec4(0.0); //If the shadow doesn't intersect the base, don't draw anything
            float faceHeight = colorMapPixel.b;
            for (int i = -1; i <= shadowSize; i++) {
                normalizedScreenCoords += canvasAngleMove;
                pos += spriteAngleMove;
                colorMapPixel = Texel(objectCanvas, normalizedScreenCoords); //shadow_coords);
                //if (colorMapPixel.b != faceHeight) return vec4(0.0); //If an occluder in way...
                if (normalizedScreenCoords.y >= baseScreenY - 0.001 &&
                    normalizedScreenCoords.y <= baseScreenY + 0.001 && 
                    normalizedScreenCoords.x >= baseScreenX1 &&
                    normalizedScreenCoords.x <= baseScreenX2) {
                    pos.y -= i*divideBy/spriteHeight;
                    vec4 new_pixel = Texel(texture, pos);
                    if (new_pixel.a != 0.0) {
                        return vec4(0.0, 0, 0, opacity); // red color
                    } else {
                        return vec4(0.0);
                        //return pixel;   //Does weird mirror stuff if you don't add this :-)
                    }
                }   
            }
        }
    //}
    return vec4(0.0); //We're only drawing the shadow 
}