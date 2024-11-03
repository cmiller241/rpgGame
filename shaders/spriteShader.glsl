extern float angle;
extern Image colorMapCanvas;
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
extern float noSunShadows;
uniform vec2 canvasSize; 
extern vec2 spotlight;   
extern float showSpotlight; 
float base = spriteTopY + spriteBase; //base plus top of sprite 80
float baseX1 = spriteLeftX + xstart;
float baseX2 = spriteLeftX + xend; 
const float PI = 3.14159265359;
float rad = angle * PI / 180.0;
vec2 spriteAngleMove = vec2(cos(rad) / spriteWidth, sin(rad) / spriteHeight);
vec2 canvasAngleMove = vec2(cos(rad) / canvasSize.x, sin(rad) / canvasSize.y);   
float baseScreenY = base / canvasSize.y;
float baseScreenX1 = baseX1 / canvasSize.x;
float baseScreenX2 = baseX2 / canvasSize.x; 
vec2 normalizedSpotlight = spotlight / canvasSize;


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
    vec2 pos = texture_coords;
    vec4 pixel = vec4(0.0);
    vec2 normalizedScreenCoords = screen_coords / canvasSize;
    if (noSunShadows != 1.0) {
        vec4 colorMapPixel = Texel(colorMapCanvas,normalizedScreenCoords);
        if (colorMapPixel.r == 1.0) {                               //If we're on a face tile
            //float faceHeight = colorMapPixel.b;
            float newY = normalizedScreenCoords.y + sin(rad) / canvasSize.y;
            bool isGoingDown = true;
            if (newY > normalizedScreenCoords.y) {                  //It's moving downwards. 
                for (int i = 1; i<= shadowSize; i++) {
                    if (colorMapPixel.r == 1.0) {
                        normalizedScreenCoords.y += 1.0 / canvasSize.y;
                        pos.y += 1.0 / spriteHeight;
                    } else {
                        if (isGoingDown == true) isGoingDown = false;
                        normalizedScreenCoords += canvasAngleMove;
                        pos += spriteAngleMove;
                    }
                    colorMapPixel = Texel(colorMapCanvas, normalizedScreenCoords);
                    if (normalizedScreenCoords.y >= baseScreenY - 0.001 &&
                        normalizedScreenCoords.y <= baseScreenY + 0.001 && 
                        normalizedScreenCoords.x >= baseScreenX1 &&
                        normalizedScreenCoords.x <= baseScreenX2) {
                        pos.y -= i*divideBy/spriteHeight;
                        vec4 new_pixel = Texel(texture, pos);
                        if (new_pixel.a != 0.0) {
                            return vec4(0.0, 0.0, 0.0, opacity);
                        }
                    }                
                }
            }
        } else {
            if (segmentsIntersect(
            normalizedScreenCoords,
            normalizedScreenCoords + shadowSize * canvasAngleMove,
            vec2(baseScreenX1, baseScreenY),
            vec2(baseScreenX2, baseScreenY)
            )) { //If the shadow doesn't intersect the base, don't draw anything
                float faceHeight = colorMapPixel.b;
                for (int i = 0; i <= shadowSize; i++) {
                    normalizedScreenCoords += canvasAngleMove;
                    pos += spriteAngleMove;
                    colorMapPixel = Texel(colorMapCanvas, normalizedScreenCoords); //shadow_coords);
                    //if (colorMapPixel.b != faceHeight) return vec4(0.0); //If an occluder in way...
                    if (normalizedScreenCoords.y >= baseScreenY - 0.003 &&
                        normalizedScreenCoords.y <= baseScreenY + 0.003 && 
                        normalizedScreenCoords.x >= baseScreenX1 &&
                        normalizedScreenCoords.x <= baseScreenX2) {
                        pos.y -= i*divideBy/spriteHeight;
                        vec4 new_pixel = Texel(texture, pos);
                        if (new_pixel.a != 0.0) {
                            //return vec4(0.0, 0.0, 1.0, opacity); // red color
                            pixel.b = 0.1;
                            pixel.a = 1.0;
                        } else {
                            break; //return vec4(0.0);
                            //return pixel;   //Does weird mirror stuff if you don't add this :-)
                        }
                    }   
                }
            }
        }
    }

    //SPOTLIGHT SHADOWS
    if (showSpotlight == 1.0) {
        vec2 diff = spotlight - screen_coords;
        if (length(diff) > 150.0) return pixel;
        pos = texture_coords;
        vec2 normalizedDiff = normalize(diff);
        vec2 spriteAngleMove = normalizedDiff / vec2(spriteWidth,spriteHeight);
        vec2 canvasSpotlightAngleMove = normalizedDiff / canvasSize;
        normalizedScreenCoords = screen_coords / canvasSize;
        float dist = distance(texture_coords, normalizedSpotlight);
        for (int i = 0; i <= shadowSize; i++) {
            if (length(diff) < i) break;                            //This keeps shadow mirroring from happening on other side of spotlight center
            normalizedScreenCoords += canvasSpotlightAngleMove;
            pos += spriteAngleMove;
            //float distToOccluder = distance(pos, texture_coords);
            if (normalizedScreenCoords.y >= baseScreenY - 0.003 &&
                normalizedScreenCoords.y <= baseScreenY + 0.003 && 
                normalizedScreenCoords.x >= baseScreenX1 &&
                normalizedScreenCoords.x <= baseScreenX2) {
                pos.y -= i/spriteHeight;
                vec4 new_pixel = Texel(texture, pos);
                if (new_pixel.a != 0.0) {
                    pixel.r = 1.0;
                    pixel.a = 1.0;
                } else {
                    break;
                }
            }   
        }
    }


    return pixel;
}

