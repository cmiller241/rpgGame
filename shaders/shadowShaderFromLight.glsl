extern Image objectCanvas;
extern vec2 lightPosition;
extern float shadowSize;
const float PI = 3.14159265359;
//float rad = angle * PI / 180.0;
float transparency = 1.0;//0.33;
//float adjusted_angle = mod(angle, 360.0);
//vec2 angleMove = vec2(cos(rad) / love_ScreenSize.x, sin(rad) / love_ScreenSize.y);
//float darkness = cos((adjusted_angle + 90) * PI / 180.0) + 1;
vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 pixel = Texel(objectCanvas, texture_coords);
    vec2 pos = texture_coords;
    vec4 shadow_pixel = Texel(objectCanvas, pos);
    vec2 diff = lightPosition - screen_coords;
    float rad = atan(diff.y, diff.x);                 //Angle from pixel to light source
    vec2 angleMove = vec2(cos(rad) / love_ScreenSize.x, sin(rad) / love_ScreenSize.y);
    float dist = distance(lightPosition, screen_coords);
    if (dist > 200) return vec4(0.0);
    float theSize = shadowSize;
    if (dist < shadowSize) theSize = dist-2; 
    if (pixel.r == 1.0) {           //We start on a face tile
//        float faceHeight = pixel.b;
//        float newY = pos.y + sin(rad) / love_ScreenSize.y;
//        bool isGoingDown = true;
//        if (newY > pos.y) {     //If ray is going down, let's review for shadow  
//            for (int i=1; i<= shadowSize; i++) {
//                if (shadow_pixel.r == 1.0) {    //If current pixel is on mountain face, let's go down
//                    pos.y += 1.0 / love_ScreenSize.y;
//                } else {    //Once it hits ground, let's follow angle to see if it hits occluder
//                    if (isGoingDown == true) isGoingDown = false;
//                    pos += angleMove;
//                }
//                shadow_pixel = Texel(objectCanvas, pos);
//                if (isGoingDown == false && shadow_pixel.b >= faceHeight && shadow_pixel.g == 1.0) { //If occluder is => mountainface, and ground is between two occluders:
//                    return vec4(0.0, 0.0, 0.1, .6-darkness); //red color
//                }
//            }
//        } 
        //If angle is between 180 and 360, mountain face should be dark
        //But if angle gets less than 180, it should transition to being light
        //And if angle is more than 360, it should transition to being light
        //return vec4(0.0, 0.0, 0.0, darkness); //black color
        return vec4(0.0); //transparent
    } else {
        for (int i = -1; i <= theSize; i++) {
            pos += angleMove;
            shadow_pixel = Texel(objectCanvas, pos); //shadow_coords);

            if (shadow_pixel.g == 1.0 && shadow_pixel.b > pixel.b && shadow_pixel.b <= pixel.b + 0.15) {    
                return vec4(0.0, 0.0, 0.1, transparency); // red color
            }
        }
    }
    return vec4(0); // transparent
}    