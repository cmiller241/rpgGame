extern float angle;
extern Image colorMapCanvas;
extern float spriteWidth;
extern float spriteHeight;
extern float spriteBase;
extern float xstart;
extern float xend;
extern float shadowSize;
extern float divideBy;
extern lowp float opacity;
extern lowp float noSunShadows;
uniform vec2 canvasSize;
extern lowp vec2 spotlight;
extern lowp float showSpotlight;

const float PI = 3.14159265359;
const float stepMove = 1.0;

// Compute spriteLeftX and spriteTopY from screen_coords and texture_coords
vec2 computeSpriteOrigin(vec2 texture_coords, vec2 screen_coords) {
    // Normalize texture_coords (0 to 1)
    vec2 normalizedTexture = texture_coords;
    // Pivot offset
    float ox = 224.0;
    float oy = 224.0;
    // Compute the pixel offset within the sprite, accounting for pivot
    vec2 pixelOffset = vec2(normalizedTexture.x * spriteWidth - ox, normalizedTexture.y * spriteHeight - oy);
    // Subtract the offset from screen_coords to get the sprite's origin (xTileWidthOffsetX, yTileHeightOffsetY)
    vec2 spriteOrigin = screen_coords - pixelOffset;
    // Adjust to top-left corner (accounting for pivot again)
    spriteOrigin.x = spriteOrigin.x - ox;
    spriteOrigin.y = spriteOrigin.y - oy;
    return spriteOrigin;
}

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

vec4 effect(lowp vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec2 pos = texture_coords;
    lowp vec4 pixel = vec4(0.0);
    vec2 normalizedScreenCoords = screen_coords / canvasSize;

    // Compute sprite origin (spriteLeftX, spriteTopY)
    vec2 spriteOrigin = computeSpriteOrigin(texture_coords, screen_coords);
    float spriteLeftX = spriteOrigin.x;
    float spriteTopY = spriteOrigin.y;

    // Existing calculations using spriteLeftX and spriteTopY
    float base = spriteTopY + spriteBase;
    float baseX1 = spriteLeftX + xstart;
    float baseX2 = spriteLeftX + xend;
    float rad = angle * PI / 180.0;
    vec2 spriteAngleMove = vec2(cos(rad) / spriteWidth, sin(rad) / spriteHeight);
    vec2 canvasAngleMove = vec2(cos(rad) / canvasSize.x, sin(rad) / canvasSize.y);
    float baseScreenY = base / canvasSize.y;
    float baseScreenX1 = baseX1 / canvasSize.x;
    float baseScreenX2 = baseX2 / canvasSize.x;
    vec2 normalizedSpotlight = spotlight / canvasSize;

    if (noSunShadows != 1.0) {
        lowp vec4 colorMapPixel = Texel(colorMapCanvas, normalizedScreenCoords);
        if (colorMapPixel.r == 1.0) { // On a face tile
            float newY = normalizedScreenCoords.y + sin(rad) / canvasSize.y;
            bool isGoingDown = true;
            if (newY > normalizedScreenCoords.y) { // Moving downwards
                for (int i = 1; i <= int(shadowSize); i += int(stepMove)) {
                    if (colorMapPixel.r == 1.0) {
                        normalizedScreenCoords.y += stepMove / canvasSize.y;
                        pos.y += stepMove / spriteHeight;
                    } else {
                        if (isGoingDown) isGoingDown = false;
                        normalizedScreenCoords += canvasAngleMove * stepMove;
                        pos += spriteAngleMove * stepMove;
                    }
                    colorMapPixel = Texel(colorMapCanvas, normalizedScreenCoords);
                    if (normalizedScreenCoords.y >= baseScreenY - 0.001 &&
                        normalizedScreenCoords.y <= baseScreenY + 0.001 &&
                        normalizedScreenCoords.x >= baseScreenX1 &&
                        normalizedScreenCoords.x <= baseScreenX2) {
                        pos.y -= float(i) * divideBy / spriteHeight;
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
            )) {
                float faceHeight = colorMapPixel.b;
                for (int i = 0; i <= int(shadowSize); i += int(stepMove)) {
                    normalizedScreenCoords += canvasAngleMove * stepMove;
                    pos += spriteAngleMove * stepMove;
                    colorMapPixel = Texel(colorMapCanvas, normalizedScreenCoords);
                    if (normalizedScreenCoords.y >= baseScreenY - 0.003 &&
                        normalizedScreenCoords.y <= baseScreenY + 0.003 &&
                        normalizedScreenCoords.x >= baseScreenX1 &&
                        normalizedScreenCoords.x <= baseScreenX2) {
                        pos.y -= float(i) * divideBy / spriteHeight;
                        vec4 new_pixel = Texel(texture, pos);
                        if (new_pixel.a != 0.0) {
                            pixel.b = 0.1;
                            pixel.a = 1.0;
                        } else {
                            break;
                        }
                    }
                }
            }
        }
    }

    // SPOTLIGHT SHADOWS
    if (showSpotlight == 1.0) {
        vec2 diff = spotlight - screen_coords;
        if (length(diff) > 150.0) return pixel;
        pos = texture_coords;
        vec2 normalizedDiff = normalize(diff);
        vec2 spriteAngleMove = normalizedDiff / vec2(spriteWidth, spriteHeight);
        vec2 canvasSpotlightAngleMove = normalizedDiff / canvasSize;
        normalizedScreenCoords = screen_coords / canvasSize;
        for (int i = 0; i <= int(shadowSize); i++) {
            if (length(diff) < float(i)) break;
            normalizedScreenCoords += canvasSpotlightAngleMove;
            pos += spriteAngleMove;
            if (normalizedScreenCoords.y >= baseScreenY - 0.003 &&
                normalizedScreenCoords.y <= baseScreenY + 0.003 &&
                normalizedScreenCoords.x >= baseScreenX1 &&
                normalizedScreenCoords.x <= baseScreenX2) {
                pos.y -= float(i) / spriteHeight;
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