//extern Image offscreenCanvas;         //Canvas for grass, dirt, etc.
extern Image objectCanvas;              //Canvas of Players, NPCs, Objects
extern Image shadowCanvas;              //Canvas of Shadows for Objects (not tile content)
extern Image colorMapCanvas;            //Canvas of Color Map
extern Image lutImage;                  //LUT tables (noon, dusk, midnight, dawn, lighting)
extern float shadowAngle;               //Angle of shadow
extern float shadowSize;                //Length of shadow  
extern float shadowAlpha;               //Transparency of shadows         
extern float lutOld;                    //Old LUT y value
extern float lutNew;                    //New LUT y value
extern vec2 spotlight;                  //Spotlight {x,y}
extern vec4 spotlightColor;             //Spotlight Color vec4
extern vec2 canvasSize;                 //Canvas sizes for all canvas.
extern float normalizedAngle;           //Normalized Angle for LUT mixing
float noSpotlight = 0;                  //Set if no spotlight for pixel should be rendered
float noShadows = 0;                    //Set if you want no shadows at all
const float PI = 3.14159265359;
float rad = shadowAngle * PI / 180.0;
float angle = mod(shadowAngle, 360.0);
bool inSpotlight = true;
vec2 angleMove = vec2(cos(rad) / canvasSize.x, sin(rad) / canvasSize.y);
vec4 currentPixel;
vec2 normalizedSpotlight = spotlight / canvasSize;

vec4 effect(vec4 color, Image texture, vec2 textureCoords, vec2 screenCoords) {
    //Calculate the distance to the center of spotlight
    number dist = distance(textureCoords, normalizedSpotlight);
    
    vec4 objectPixel = Texel(objectCanvas,textureCoords);
    if (objectPixel.a != 1.0) {                                                             //If objectCanvas is not semi-transparent or empty...
        vec4 offscreenPixel = Texel(texture, textureCoords);                                //Let's check ground tiles..
        currentPixel = mix(offscreenPixel, objectPixel, objectPixel.a);                     //Object and Offscreen Pixel Combination is sufficient
        vec4 colorMapPixelOriginal = Texel(colorMapCanvas, textureCoords);                  //Let's get the colorMap data
        if (colorMapPixelOriginal.b > 0.0) {
            float brightnessFactor = colorMapPixelOriginal.b; // Elevation-based brightness factor
            currentPixel.rgb *= mix(1.0, 1.5, brightnessFactor); // Scale the RGB values up to brighten without washing out
        }                                                                  
        if (noShadows == 0.0) {                                                             //If we're checking for shadows...
            vec4 shadowPixel = Texel(shadowCanvas, textureCoords);                          //Check whether pixel coordinate has shadow...}            
            if (shadowPixel.r > 0.0) {
                inSpotlight = false;
                shadowPixel.r = 0.0;
                if (shadowPixel.b == 0.0) shadowPixel.a = 0.0;
            }
            if (shadowPixel.a != 1.0 && angle < 180 && angle > 0) {                         //If shadow is transparent or semi-transparent
                vec4 colorMapPixelOriginal = Texel(colorMapCanvas, textureCoords);
                vec2 pos = textureCoords;
                for (int i=0; i <= shadowSize; i++) {                                       //Shadow cast from sun
                    pos += angleMove;
                    vec4 colorMapPixel = Texel(colorMapCanvas, pos);
                    if (colorMapPixelOriginal.r != 1.0 && colorMapPixel.g != 0.0 && colorMapPixel.b > colorMapPixelOriginal.b) {    
                        shadowPixel = vec4(0.0,0.0,0.0,1.0);
                        //vec4 shadowedOffscreenPixel = mix(offscreenPixel, shadowPixel, shadowPixel.a);
                        //currentPixel = mix(shadowedOffscreenPixel, objectPixel, objectPixel.a);
                        break;
                    }               
                }
            }
            if (shadowPixel.a != 0.0 && angle < 180 && angle > 0) {                        //Mix shadow, grass, & partially transparent object pixel together, if needed
                vec4 shadowedOffscreenPixel = mix(offscreenPixel, shadowPixel, shadowPixel.a * shadowAlpha);
                currentPixel = mix(shadowedOffscreenPixel, objectPixel, objectPixel.a);
            }
        }
        if (noSpotlight != 1.0) {                                                           //Let's do spotlight shadows now
            vec2 pos = textureCoords;
            vec2 direction = normalize(normalizedSpotlight - textureCoords);
            vec4 shadow_pixel = Texel(colorMapCanvas, pos);
            vec4 colorMapPixelOriginal = shadow_pixel;
            float stepSize = 1.0 / shadowSize / 20;                                         //Dividing by 20 makes the shadow really straight. 
            if (shadow_pixel.r == 1.0) {                                                    //If on pillar, light shows up in front but not behind. 
                while (shadow_pixel.r == 1.0 && pos.y <= normalizedSpotlight.y) {           //Go down pillar until we find base of pillar or until below player 
                    pos.y += stepSize;
                    shadow_pixel = Texel(colorMapCanvas, pos);
                }
                if (pos.y > normalizedSpotlight.y) inSpotlight = false;
            } else if (shadow_pixel.b > 0.0) {
                inSpotlight = false;
            } else {
                for (int i = 0; i <= shadowSize*3; i++) {
                    pos += direction * stepSize;
                    shadow_pixel = Texel(colorMapCanvas, pos); //shadow_coords
                    float distToOccluder = distance(pos, textureCoords);
                    if (shadow_pixel.r == 1.0 && shadow_pixel.g == 1.0 
                    && shadow_pixel.b > colorMapPixelOriginal.b 
                    && shadow_pixel.b <= colorMapPixelOriginal.b + 0.15 
                    && dist > distToOccluder) {    
                        inSpotlight = false;//return vec4(0.0, 0.0, 0.3, 1.0); // red color
                        break;
                    }
                }
            }
        }
    } else {
        currentPixel = objectPixel;
    }

    //LUT Time
    vec3 normalizedColor = currentPixel.rgb * 31.0;                                         //Normalize the colors 0 - 31 (32 values)

    // Calculate the LUT image coordinates
    vec2 lutCoords1;                        
    vec2 lutCoords2;

    normalizedColor.b = floor(normalizedColor.b);                                           //Blue value needs to be integer, or weird stuff happens

    lutCoords1.x = (normalizedColor.b * 32.0 + normalizedColor.r) / 1023.0;                 
    lutCoords1.y = (lutNew + 31.0 - normalizedColor.g + 0.5) / 127.0;
    lutCoords2.x = (normalizedColor.b * 32.0 + normalizedColor.r) / 1023.0;
    lutCoords2.y = (lutOld + 31.0 - normalizedColor.g + 0.5) / 127.0;

    // Sample the LUT image
    vec4 lutColor1 = Texel(lutImage, lutCoords1);
    vec4 lutColor2 = Texel(lutImage, lutCoords2);

    // Interpolate between lutColor1 and lutColor2 based on normalized angle
    vec4 outputColor = mix(lutColor1, lutColor2, normalizedAngle);

    // Return the color from the LUT image
    //return outputColor;


    //SPOTLIGHT CODE 
    //Normalize the distance based on the radius
    float radius = 100.0;
    float theDistance = distance(screenCoords, spotlight);

    float normalizedDist = clamp(theDistance / radius, 0.0, 1.0);

    //number t = clamp(dist / radius, 0.0, 1.0);

    //Interpolate between the two colors based on the normalized distance 
    vec4 finalColor = mix(currentPixel, outputColor, normalizedDist);
    return mix(outputColor, finalColor, float(inSpotlight));


}

