            vec2 diff = normalizedSpotlight - textureCoords;
            float rad2 = atan(diff.y, diff.x);                 //Angle from pixel to light source
            vec2 angleMove2 = vec2(cos(rad2) / canvasSize.x, sin(rad2) / canvasSize.y);
            vec2 pos = textureCoords;
            vec4 shadow_pixel = Texel(colorMapCanvas, pos);
            vec4 colorMapPixelOriginal = shadow_pixel;
            return vec4(1.0);
            for (int i=0; i <= shadowSize; i++) {
                pos += angleMove2;
                shadow_pixel = Texel(colorMapCanvas, pos);

                if (shadow_pixel.r == 0.0 && shadow_pixel.g == 1.0) { // && shadow_pixel.b > colorMapPixelOriginal.b && shadow_pixel.b <= colorMapPixelOriginal.b + 0.15) {    
                    //inSpotlight = false;
                    currentPixel = vec4(1.0, 0.0, 0.0, 1.0); // red color
                    return currentPixel;
                }
            }