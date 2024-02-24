local angle=0
local shadowSize = 50;
local shadowCanvas = love.graphics.newCanvas()
local objectCanvas = love.graphics.newCanvas()
local shadowShader = love.graphics.newShader[[
    extern Image objectCanvas;
    extern float angle;
    extern float shadowSize;
    const float PI = 3.14159265359;
    float rad = angle * PI / 180.0;
    float transparency = 0.5;
    float adjusted_angle = mod(angle, 360.0);
    vec2 angleMove = vec2(cos(rad) / love_ScreenSize.x, sin(rad) / love_ScreenSize.y);
    float darkness = 1-(0.5 + 0.5 * cos((adjusted_angle - 90.0) * PI / 180.0));
    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
        vec4 pixel = Texel(objectCanvas, texture_coords);
        vec2 pos = texture_coords;
        vec4 shadow_pixel = Texel(objectCanvas, pos);
        if (pixel.r == 1.0) {
            float faceHeight = pixel.b;
            float newY = pos.y + sin(rad) / love_ScreenSize.y;
            bool isGoingDown = true;
            if (newY > pos.y) {     //If ray is going down, let's review for shadow  
                for (int i=1; i<= shadowSize; i++) {
                    if (shadow_pixel.r == 1.0) {    //If current pixel is on mountain face, let's go down
                        pos.y += 1.0 / love_ScreenSize.y;
                    } else {    //Once it hits ground, let's follow angle to see if it hits occluder
                        if (isGoingDown == true) isGoingDown = false;
                        pos += angleMove;
                    }
                    shadow_pixel = Texel(objectCanvas, pos);
                    if (shadow_pixel.b >= faceHeight && isGoingDown == false) { //If occluder is => mountainface, and ground is between two occluders:
                        return vec4(1.0, 0.0, 0.0, transparency); //red color
                    }
                }
            } 
            //If angle is between 180 and 360, mountain face should be dark
            //But if angle gets less than 180, it should transition to being light
            //And if angle is more than 360, it should transition to being light
            return vec4(1.0, 0.0, 0.0, darkness); //black color
        } else {
            for (int i = -1; i <= shadowSize; i++) {
                pos += angleMove;
                shadow_pixel = Texel(objectCanvas, pos); //shadow_coords);
                if (shadow_pixel.g == 1.0 && shadow_pixel.b > pixel.b && shadow_pixel.b <= pixel.b + 0.15) {    
                    return vec4(1.0, 0.0, 0.0, transparency); // red color
                }
            }
        }
        return vec4(0.0); // transparent
    }    
]]
local spriteShader = love.graphics.newShader[[
    extern float angle;
    extern Image objectCanvas;
    extern float spriteLeftX;
    extern float spriteTopY;
    extern float spriteWidth;
    extern float spriteHeight;
    float base = spriteTopY + 80;
    float baseX1 = spriteLeftX + 74;
    float baseX2 = spriteLeftX + 103;
    const float PI = 3.14159265359;
    float rad = angle * PI / 180.0;
    float shadowSize=200.0;
    vec2 spriteAngleMove = vec2(cos(rad) / spriteWidth, sin(rad) / spriteHeight);
    vec2 canvasAngleMove = vec2(cos(rad) / love_ScreenSize.x, sin(rad) / love_ScreenSize.y);    
    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
        vec4 pixel = Texel(texture, texture_coords);
        if (pixel.a == 0.0) {
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
                        if (normalizedScreenCoords.y >= base / love_ScreenSize.y - 0.001 &&
                            normalizedScreenCoords.y <= base / love_ScreenSize.y + 0.001 && //base / love_ScreenSize.y &&
                            normalizedScreenCoords.x >= baseX1 / love_ScreenSize.x &&
                            normalizedScreenCoords.x <= baseX2 / love_ScreenSize.x) {
                            pos.y -= i/spriteHeight;
                            vec4 new_pixel = Texel(texture, pos);
                            if (new_pixel.a == 1.0) {
                                return vec4(0.0, 0.0, 0.0, 0.5);
                            }
                        }                
                    }
                }
            } else {
                for (int i = -1; i <= shadowSize; i++) {
                    normalizedScreenCoords += canvasAngleMove;
                    pos += spriteAngleMove;
                    colorMapPixel = Texel(objectCanvas, normalizedScreenCoords); //shadow_coords);
                    if (normalizedScreenCoords.y >= base / love_ScreenSize.y - 0.001 &&
                        normalizedScreenCoords.y <= base / love_ScreenSize.y + 0.001 && //base / love_ScreenSize.y &&
                        normalizedScreenCoords.x >= baseX1 / love_ScreenSize.x &&
                        normalizedScreenCoords.x <= baseX2 / love_ScreenSize.x) {
                        pos.y -= i/spriteHeight;
                        vec4 new_pixel = Texel(texture, pos);
                        if (new_pixel.a == 1.0) {
                            //return vec4(new_pixel.r, new_pixel.g, new_pixel.b, 0.5); // red color
                            return vec4(0.0, 0, 0, 0.5); // red color
                        } else {
                            return pixel;   //Does weird mirror stuff if you don't add this :-)
                        }
                    }   
                }
            }
        }
        return pixel;
    }
]]
local fartShader = love.graphics.newShader[[
    extern float angle;
    //extern Image objectCanvas;
    const float PI = 3.14159265359;
    float rad = angle * PI / 180.0;
    float shadowSize=64;
    vec2 angleMove = vec2(cos(rad) / 112, sin(rad) / 112);
    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
        vec4 pixel = Texel(texture, texture_coords);
        if (pixel.a == 0.0) {
            vec2 pos = texture_coords;
            for (int i = 1; i <= shadowSize; i++) {
                pos += angleMove;
                vec4 new_pixel = Texel(texture, pos); //shadow_coords); //Why does this need to be declared here?
                if (pos.y > (80.0 / 112 - 0.01) && pos.y < (80.0 / 112 + 0.01)
                    && pos.x > (45.0 / 112 - 0.01) && pos.x < (75.0 / 112 + 0.01)) {   
                    pos.y -= i/112.0;
                    new_pixel = Texel(texture, pos);
                    if (new_pixel.a == 1.0) {
                        return vec4(1.0, 0, 0, 0.5); // red color
                    }
                    //return pixel;
                }
            }
        }
        return pixel;
        //return vec4(0.0); // transparent
    }
]]
local tileSize = 80

function love.resize(w,h)
    shadowCanvas = love.graphics.newCanvas(w,h)
    objectCanvas = love.graphics.newCanvas(w,h)
end

function love.load()
    love.window.setMode(1280, 800, {resizable=true, vsync=false, minwidth=400, minheight=300})
    love.window.setTitle("RPG")
    love.graphics.setDefaultFilter("nearest", "nearest")
    hero = love.graphics.newImage("img/onehero.png")
end

function love.update(dt)
    local speed = 20 -- change this to control the speed of angle change

    if love.keyboard.isDown('up') then
        angle = angle + speed * dt
    end

    if love.keyboard.isDown('down') then
        angle = angle - speed * dt
        if angle < 0 then
            angle = 0
        end
    end

    if love.keyboard.isDown('right') then
       shadowSize = shadowSize + 1;
    end

    if love.keyboard.isDown('left') then
       shadowSize = shadowSize - 1;
       if shadowSize < 0 then
           shadowSize = 0
       end
    end
end

function love.draw()
    --R = Face; G = Occluder; B = Height
    love.graphics.setCanvas(objectCanvas)
    love.graphics.clear()
    love.graphics.setColor(1,1,.1)              --First layer occluders and face
    love.graphics.rectangle("fill", tileSize*11, tileSize*5, tileSize, tileSize)
    love.graphics.rectangle("fill", tileSize*10, tileSize*5, tileSize, tileSize)
    love.graphics.rectangle("fill", tileSize*9, tileSize*6, tileSize, tileSize)
    love.graphics.rectangle("fill", tileSize*7, tileSize*5, tileSize, tileSize)
    love.graphics.rectangle("fill", tileSize*8, tileSize*5, tileSize, tileSize)
    love.graphics.rectangle("fill", tileSize*7+30, tileSize*6+20, 32, 2)
    love.graphics.rectangle("fill", tileSize*9+30, tileSize*7+30, 128,2)
    --love.graphics.setColor(0,1,.1)              --First layer occluder NO face
    --love.graphics.rectangle("fill", tileSize*8, tileSize*4, tileSize, tileSize)
    love.graphics.setColor(0,0,.5)              --First layer grass
    love.graphics.rectangle("fill", tileSize*7, tileSize*4, tileSize, tileSize)
    love.graphics.rectangle("fill", tileSize*9, tileSize*4, tileSize, tileSize)
    love.graphics.rectangle("fill", tileSize*9, tileSize*5, tileSize, tileSize)
    love.graphics.rectangle("fill", tileSize*8, tileSize*4, tileSize, tileSize)
    love.graphics.rectangle("fill", tileSize*10, tileSize*4, tileSize, tileSize)
    love.graphics.rectangle("fill", tileSize*10, tileSize*3, tileSize, tileSize)
    love.graphics.setColor(1,1,.6)              --Second layer occluders and face
    love.graphics.rectangle("fill",tileSize*11, tileSize*4,tileSize,tileSize)
    love.graphics.rectangle("fill",tileSize*9,tileSize*3, tileSize, tileSize)
    love.graphics.rectangle("fill",tileSize*8,tileSize*3, tileSize, tileSize)
    love.graphics.setColor(0,0,.6)              --Second layer grass
    love.graphics.rectangle("fill",tileSize*9,tileSize*2, tileSize, tileSize)
    love.graphics.rectangle("fill",tileSize*8,tileSize*2, tileSize, tileSize)
    love.graphics.rectangle("fill",tileSize*11,tileSize*3, tileSize, tileSize)

    love.graphics.setColor(1,1,1)
    love.graphics.setCanvas(shadowCanvas)
    love.graphics.clear()
    love.graphics.setShader(shadowShader)
    shadowShader:send("angle", angle)
    shadowShader:send("shadowSize", shadowSize)
    shadowShader:send("objectCanvas", objectCanvas) 
    love.graphics.draw(objectCanvas)
    --love.graphics.rectangle("fill",0,0,love.graphics.getWidth(),love.graphics.getHeight())
    love.graphics.setShader()
    love.graphics.setCanvas()
    love.graphics.draw(objectCanvas,0,0)
    love.graphics.draw(shadowCanvas,0,0)
    love.graphics.setShader(spriteShader)
    spriteShader:send("angle", angle)
    spriteShader:send("objectCanvas", objectCanvas)
    spriteShader:send("spriteLeftX", 800)
    spriteShader:send("spriteTopY", 430) 
    spriteShader:send("spriteHeight", 144)
    spriteShader:send("spriteWidth", 176) 
    love.graphics.draw(hero,800,430)
    love.graphics.setShader()


    love.graphics.print("Angle: " .. angle, 10, 10)
end

