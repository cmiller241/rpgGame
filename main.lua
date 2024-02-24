local scaleX = 1
local scaleY = 1
local increasing = true
local playerX = 10
local playerY = 10
local playerSpeed = 200
local tileSize = 32
local mapArray
local spriteSheet
local sprites
local heroSheet
local heroQuads
local grassSheet
local grassQuad 
local treeSheet
local treeTrunk
local treeFoliage
local brokenYC
local brokenXC
local brokenHash
local angle = 40
local shadowSize = 32
local showColorMap = false
local dx = 200  --Distance from light source x
local dy = 300  --Distance from light source y 
local objectCanvas = love.graphics.newCanvas()
local shadowCanvas = love.graphics.newCanvas()
local colorMapCanvas = love.graphics.newCanvas()
local tempCanvas = love.graphics.newCanvas(200*scaleX,200*scaleY)
local gradientShader = love.graphics.newShader[[
    extern vec4 rect;

    vec4 effect(vec4 color, Image texture, vec2 textureCoords, vec2 screenCoords) {
        // Calculate the gradient factor
        number gradient = 0.3 * (screenCoords.y - rect.y) / rect.w;

        // Create a color that goes from black at the bottom to transparent at the top
        vec4 gradientColor = vec4(0.0, 0.0, 0.0, gradient);

        // Apply the gradient color
        return gradientColor;
    }
]]
local lightShader = love.graphics.newShader[[
    extern vec2 lightPosition;
    extern number lightIntensity;
    extern Image normalMap;

    vec4 effect(vec4 color, Image texture, vec2 textureCoords, vec2 screenCoords) {
        // Get the color and normal from the texture and normal map
        vec4 pixelColor = Texel(texture, textureCoords);
        vec3 normal = Texel(normalMap, textureCoords).rgb;

        // Transform the normal from [0,1] to [-1,1]
        normal = normal * 2.0 - 1.0;

        // Calculate the light direction  
        vec2 lightDir = lightPosition - screenCoords;
        float distance = length(lightDir);

        // Normalize the light direction
        lightDir = lightDir / distance;

        // Calculate the diffuse light intensity
        float diffuse = max(dot(normal, vec3(lightDir, 0.0)), 0.0);

        // Attenuate the light based on distance
        diffuse = diffuse * (1.0 / (1.0 + (0.01 * distance * distance)));   

        // Apply the light to the color
        vec4 litColor = vec4(pixelColor.rgb * diffuse * lightIntensity, pixelColor.a);

        return litColor;
    }
]]

local brightenShader = love.graphics.newShader[[
    extern number brightness;

    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
        // Sample the pixel from the texture
        vec4 pixel = Texel(texture, texture_coords);
        
        // Multiply each color channel by the brightness factor
        pixel.r *= brightness;
        pixel.g *= brightness;
        pixel.b *= brightness;
        
        // Clamp the values to the range [0, 1] to avoid overflow
        pixel.r = clamp(pixel.r, 0.0, 1.0);
        pixel.g = clamp(pixel.g, 0.0, 1.0);
        pixel.b = clamp(pixel.b, 0.0, 1.0);
        
        return pixel;
    }
]]

local combinedShader = love.graphics.newShader[[
    extern number hueAdjust;
    extern number time;

    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
        vec2 displacement = vec2(sin(texture_coords.x * texture_coords.y * 10.0 + time) * 0.005, 0.0);
        vec4 pixel = Texel(texture, texture_coords + displacement/2.0);

        // RGB to HSV
        float maxC = max(pixel.r, max(pixel.g, pixel.b));
        float minC = min(pixel.r, min(pixel.g, pixel.b));
        float delta = maxC - minC;

        float hue = 0.0;
        if (delta != 0.0) {
            if (maxC == pixel.r) {
                hue = ((pixel.g - pixel.b) / delta);
            } else if (maxC == pixel.g) {
                hue = ((pixel.b - pixel.r) / delta) + 2.0;
            } else {
                hue = ((pixel.r - pixel.g) / delta) + 4.0;
            }
            hue = mod((hue * 60.0) + 360.0 + hueAdjust, 360.0);
        }
        float saturation = (maxC != 0.0) ? delta / maxC : 0.0;
        float value = maxC;

        // HSV to RGB
        float c = value * saturation;
        float x = c * (1.0 - abs(mod(hue / 60.0, 2.0) - 1.0));
        float m = value - c;

        vec4 hsv;
        if (0.0 <= hue && hue < 60.0) {
            hsv = vec4(c, x, 0.0, pixel.a);
        } else if (60.0 <= hue && hue < 120.0) {
            hsv = vec4(x, c, 0.0, pixel.a);
        } else if (120.0 <= hue && hue < 180.0) {
            hsv = vec4(0.0, c, x, pixel.a);
        } else if (180.0 <= hue && hue < 240.0) {
            hsv = vec4(0.0, x, c, pixel.a);
        } else if (240.0 <= hue && hue < 300.0) {
            hsv = vec4(x, 0.0, c, pixel.a);
        } else {
            hsv = vec4(c, 0.0, x, pixel.a);
        }
        hsv.rgb += m;

        return hsv * color;
    }
]]

local leavesShader = love.graphics.newShader[[
    extern number time;
    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
        vec2 displacement = vec2(sin(texture_coords.x * texture_coords.y * 10.0 + time) * 0.005, 0.0);
        vec4 pixel = Texel(texture, texture_coords + displacement);
        return pixel * color;
    }
]]

local grassShader = love.graphics.newShader[[
    extern number time;

    vec4 position(mat4 transform_projection, vec4 vertex_position) {
        float movement = sin(time + vertex_position.y / 100.0) * pow(vertex_position.y / 100.0, 2.0);
        vertex_position.x += movement * 0.1;
        return transform_projection * vertex_position;
    }
]]

local shadowShader = love.graphics.newShader[[
    extern Image objectCanvas;
    extern float angle;
    extern float shadowSize;
    const float PI = 3.14159265359;
    float rad = angle * PI / 180.0;
    float transparency = 1.0;//0.33;
    float adjusted_angle = mod(angle, 360.0);
    vec2 angleMove = vec2(cos(rad) / love_ScreenSize.x, sin(rad) / love_ScreenSize.y);
    float darkness = cos((adjusted_angle + 90) * PI / 180.0) + 1;
    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
        vec4 pixel = Texel(objectCanvas, texture_coords);
        vec2 pos = texture_coords;
        vec4 shadow_pixel = Texel(objectCanvas, pos);
        if (pixel.r == 1.0) {           //We start on a face tile
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
                    if (isGoingDown == false && shadow_pixel.b >= faceHeight && shadow_pixel.g == 1.0) { //If occluder is => mountainface, and ground is between two occluders:
                        return vec4(0.0, 0.0, 0.0, .6-darkness); //red color
                    }
                }
            } 
            //If angle is between 180 and 360, mountain face should be dark
            //But if angle gets less than 180, it should transition to being light
            //And if angle is more than 360, it should transition to being light
            //return vec4(0.0, 0.0, 0.0, darkness); //black color
            return vec4(0.0); //transparent
        } else {
            for (int i = -1; i <= shadowSize; i++) {
                pos += angleMove;
                shadow_pixel = Texel(objectCanvas, pos); //shadow_coords);
                if (shadow_pixel.g == 1.0 && shadow_pixel.b > pixel.b && shadow_pixel.b <= pixel.b + 0.15) {    
                    return vec4(0.0, 0.0, 0.0, transparency); // red color
                }
            }
        }
        return vec4(0); // transparent
    }    
]]
local spriteShader = love.graphics.newShader[[
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
        if (pixel.a != 1.0) {
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
                                return vec4(0, 0, 0, 1);
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
                            return vec4(0.0, 0, 0, 1); // red color
                        } else {
                            return pixel;   //Does weird mirror stuff if you don't add this :-)
                        }
                    }   
                }
            }
        }
        return vec4(0.0); //We're only drawing the shadow 
    }
]]


function love.load()
    love.window.setMode(640, 360, {resizable=true, vsync=false, minwidth=400, minheight=300})
    love.window.setTitle("RPG")
    love.graphics.setDefaultFilter("nearest", "nearest")

    mapArray = require("maps.map01");

    spriteSheet = love.graphics.newImage("img/sprites2.png")
    grassSheet = love.graphics.newImage("img/grass.png")
    heroSheet = love.graphics.newImage("img/sprites-fixedgrid.png")    
    treeSheet = love.graphics.newImage("img/tree3.png")
    grunge = love.graphics.newImage("/img/grunge3.jpg")
    hero = love.graphics.newImage("img/onehero.png")

    sprites = {}
    heroQuads = {}

    --Create quads for sprites
    for i = 1, math.ceil(spriteSheet:getHeight() / tileSize) do
        for j = 1, math.ceil(spriteSheet:getWidth() / tileSize) do
            sprites[(i - 1) * math.ceil(spriteSheet:getWidth() / tileSize) + j] = love.graphics.newQuad((j-1) * tileSize, (i-1) * tileSize, tileSize, tileSize, spriteSheet:getDimensions())        
        end
    end  

    --Create quads for hero
    for i = 1, math.ceil(heroSheet:getHeight() / 112) do
        for j = 1, math.ceil(heroSheet:getWidth() / 112) do
            heroQuads[(i - 1) * math.ceil(heroSheet:getWidth() / 112) + j] = love.graphics.newQuad((j-1) * 112, (i-1) * 112, 112, 112, heroSheet:getDimensions())        
        end
    end
    
    --Create quads for tree and grass
    grassQuad = love.graphics.newQuad(1280,0,32,27, grassSheet:getDimensions())
    treeTrunk = love.graphics.newQuad(0, 0, 480, 480, treeSheet:getDimensions())
    treeFoliage = love.graphics.newQuad(480,0,480,480, treeSheet:getDimensions())
end

function love.resize(w, h)
    objectCanvas = love.graphics.newCanvas(w, h)
    shadowCanvas = love.graphics.newCanvas(w, h)   
    colorMapCanvas = love.graphics.newCanvas(w, h)
    tempCanvas = love.graphics.newCanvas(200*scaleX,200*scaleY)
end

function love.keypressed(key)
    if key == "c" then
        showColorMap = not showColorMap
    end
end

function love.update(dt)
    if love.keyboard.isDown("right") then
        playerX = playerX + playerSpeed * dt
    end
    if love.keyboard.isDown("left") then
        playerX = playerX - playerSpeed * dt
        if playerX < 0 then
            playerX = 0
        end
    end
    if love.keyboard.isDown("up") then
        playerY = playerY - playerSpeed * dt
        if playerY < 0 then
            playerY = 0
        end
    end
    if love.keyboard.isDown("down") then
        playerY = playerY + playerSpeed * dt
    end
    if love.keyboard.isDown("z") then
        scaleX = scaleX + 0.01
        scaleY = scaleX
        tempCanvas = love.graphics.newCanvas(200*scaleX,200*scaleY)
    end
    if love.keyboard.isDown("x") then
        scaleX = scaleX - 0.01
        scaleY = scaleX
        tempCanvas = love.graphics.newCanvas(200*scaleX,200*scaleY)
    end 
    
    local speed = 20 -- change this to control the speed of angle change
    if love.keyboard.isDown('m') then
        angle = angle + speed * dt
    end
    if love.keyboard.isDown('n') then
        angle = angle - speed * dt
        if angle < 0 then
            angle = 0
        end
    end

end

function love.draw()
    --windowWidth = 1920
    --windowHeight = 1080

    love.graphics.setCanvas(objectCanvas)
    love.graphics.clear()
    love.graphics.setCanvas(shadowCanvas)
    love.graphics.clear()
    love.graphics.setCanvas(colorMapCanvas)
    love.graphics.clear()
    love.graphics.setCanvas()

    local windowWidth, windowHeight = love.graphics.getDimensions()
    local tilesHorizontal = math.ceil(windowWidth / (tileSize * scaleX))
    local tilesVertical = math.ceil(windowHeight / (tileSize * scaleY))

    local cameraX = playerX - windowWidth / 2 / scaleX
    local cameraY = playerY - windowHeight / 2 / scaleY
    if cameraX < 0 then cameraX = 0 end
    if cameraY < 0 then cameraY = 0 end 

    local firstTileX = math.floor(cameraX / tileSize)
    local firstTileY = math.floor(cameraY / tileSize)
    local offsetX = cameraX % tileSize
    local offsetY = cameraY % tileSize 
    
    for y = 1, tilesVertical + 10 do                             --+10 because of the damn trees. 
        local yC = firstTileY + y
        if yC < 1 or yC > #mapArray then goto continueY end
        for x = -5, tilesHorizontal + 5 do                          --+5 because of the damn trees.
            local xC = firstTileX + x
            if xC < 1 or xC > #mapArray[yC] then goto continueX end
            local xTileWidthOffsetX = (x-1)*tileSize - offsetX;
            local yTileHeightOffsetY = (y-1)*tileSize - offsetY;

            local tile = mapArray[yC][xC][1]
            local z = mapArray[yC][xC][2]
            local zHeight = z / tileSize

            if tile == 1 or tile == 10 or tile > 500 then                         --Draw grass    
                local tempTile = 1
                local brighten = 1.0;
                
                --Bitwising Time
                if (yC - 1 > 1 and mapArray[yC-1][xC][2] <= z) then tempTile = tempTile + 1 end
                if (xC + 1 < #mapArray[yC] and mapArray[yC][xC+1][2] <= z) then tempTile = tempTile + 2 end
                if (xC > 1 and mapArray[yC][xC-1][2] <= z) then tempTile = tempTile + 4 end

                if z < 0 then
                    local occluder = 0                      --Color Map High Level Grass
                    local face = 0
                    local level = (zHeight * -0.1)
                    love.graphics.setColor(face,occluder,level)
                    love.graphics.setCanvas(colorMapCanvas)
                    love.graphics.rectangle(
                        "fill",
                        xTileWidthOffsetX * scaleX,
                        yTileHeightOffsetY * scaleY + z * scaleY,
                        tileSize * scaleX,
                        tileSize * scaleY
                    )
                    love.graphics.setColor(1,1,1,1)
                    love.graphics.setCanvas()
                end

                if zHeight ~= 0 then 
                    brighten = brighten + zHeight * 0.05 * -1
                end
                brightenShader:send("brightness", brighten)
                love.graphics.setShader(brightenShader)

                love.graphics.draw(
                    spriteSheet, 
                    sprites[tempTile], 
                    xTileWidthOffsetX * scaleX,
                    yTileHeightOffsetY * scaleY + z * scaleY,
                    0, 
                    scaleX, 
                    scaleY
                )
                love.graphics.setShader()

                --Delete objects / shadows behind heightened tiles. 
                if (z < 0) then
                    love.graphics.setColor(0,0,0,0)
                    love.graphics.setBlendMode('replace')
                    love.graphics.setCanvas(objectCanvas)
                    love.graphics.rectangle(
                        'fill',
                        xTileWidthOffsetX * scaleX,
                        yTileHeightOffsetY * scaleY + z * scaleY,
                        tileSize * scaleX,
                        tileSize * scaleY
                    )
                    love.graphics.setCanvas(shadowCanvas)
                    love.graphics.rectangle(
                        'fill',
                        xTileWidthOffsetX * scaleX,
                        yTileHeightOffsetY * scaleY + z * scaleY,
                        tileSize * scaleX,
                        tileSize * scaleY
                    )
                    love.graphics.setBlendMode('alpha')
                    love.graphics.setColor(1,1,1,1)
                    love.graphics.setCanvas()
                end

            end

            --This will draw foliage on the grass. 
            if tile == 1 then
                local seed = yC * xC * 2000
                local random = prng(seed)
                local hash = math.floor(random * 12 + 1)
                hash = hash + 10

                if hash < 1 then hash = 12 end
                if hash > 220 then 
                    brokenXC = xC
                    brokenYC = yC
                    brokenHash = hash
                    hash = 12
                end
                love.graphics.draw(
                    spriteSheet,
                    sprites[hash],
                    xTileWidthOffsetX * scaleX,
                    yTileHeightOffsetY * scaleY + z * scaleY,
                    0,
                    scaleX,
                    scaleY
                )
            end

            if (z < 0) then
                local gradientGleam = 3

                for i = 0, zHeight+1, -1 do
                    local mSprite = 23
                
                    --Bitwising Time!
                    if (mapArray[yC][xC+1][2] / tileSize < i) then
                        mSprite = mSprite + 1
                        gradientGleam = 3
                    end
                    if (mapArray[yC][xC-1][2] / tileSize < i) then
                        mSprite = mSprite + 2
                        gradientGleam = 0
                    end
                    if (zHeight < -1) then mSprite = mSprite + 4 end
                    if (i ~= 0 and i ~= zHeight) then mSprite = mSprite + 4 end
                    if (i == zHeight+1 and i ~= 0) then mSprite = mSprite + 4 end

                    love.graphics.setCanvas()--(objectCanvas)
                    love.graphics.draw(
                        spriteSheet,
                        sprites[mSprite],
                        xTileWidthOffsetX * scaleX,
                        (yTileHeightOffsetY + i*tileSize) * scaleY,
                        0,
                        scaleX,
                        scaleY
                    )

                    local occluder = 0                      --Color Map the Mountain
                    local face = 1
                    local level = (i - 1) * -0.1
                    if mapArray[yC + i][xC][2] < 0 then     --If tile behind mountain is occluder...
                        occluder = 1                        --the tile space should remain an occluder
                        level = 0.1     --Level needs to be ground. But this will need to be adjusted.
                    end
                    if mapArray[yC + 1][xC][2] > z          --If tile in front of mountain is lower...  
                        and mapArray[yC+1][xC][2] <= z + tileSize then     --But not by too much...
                        occluder = 1                        --Then it's an occluder. 
                        level = (i - 1) * -0.1
                    end 
                    if mapArray[yC + 1][xC+1][2] > z          --If tile in front of mountain is lower...  
                        and mapArray[yC+1][xC+1][2] <= z + tileSize then     --But not by too much...
                        occluder = 1                        --Then it's an occluder. 
                        level = (i - 1) * -0.1
                    end 
                    if mapArray[yC][xC+1][2] > z          --If tile in front of mountain is lower...  
                        and mapArray[yC][xC+1][2] <= z + tileSize then     --But not by too much...
                        occluder = 1                        --Then it's an occluder. 
                        level = (i - 1) * -0.1
                    end 
                    if (i == 0) then occluder = 1 end
                    love.graphics.setColor(face,occluder,level)
                    love.graphics.setCanvas(colorMapCanvas)
                    love.graphics.rectangle(
                        "fill",
                        xTileWidthOffsetX * scaleX,
                        (yTileHeightOffsetY + i*tileSize) * scaleY,
                        tileSize * scaleX,
                        tileSize * scaleY
                    )
                    
                    --Delete shadows and object behind mountain face
                    love.graphics.setColor(0,0,0,0)
                    love.graphics.setBlendMode('replace')
                    love.graphics.setCanvas(shadowCanvas)
                    love.graphics.rectangle(
                        'fill',
                        xTileWidthOffsetX * scaleX,
                        (yTileHeightOffsetY + i*tileSize) * scaleY,
                        tileSize * scaleX,
                        tileSize * scaleY
                    )
                    love.graphics.setCanvas(objectCanvas)
                    love.graphics.rectangle(
                        'fill',
                        xTileWidthOffsetX * scaleX,
                        (yTileHeightOffsetY + i*tileSize) * scaleY,
                        tileSize * scaleX,
                        tileSize * scaleY
                    )
                    love.graphics.setBlendMode('alpha')
                    love.graphics.setColor(1,1,1,1)
                    
                    love.graphics.setCanvas()
                end


                love.graphics.setShader(gradientShader)
                love.graphics.setColor(0,0,0,0)
                gradientShader:send("rect", {xTileWidthOffsetX * scaleX, yTileHeightOffsetY * scaleY + z*scaleY + tileSize, tileSize * scaleX, tileSize * scaleY * zHeight * -1})
                love.graphics.rectangle(
                    'fill',
                    xTileWidthOffsetX*scaleX + gradientGleam*scaleX,
                    (yTileHeightOffsetY + z + tileSize) * scaleY,
                    tileSize * scaleX - gradientGleam*scaleX,
                    tileSize * scaleX * zHeight * -1
                )
                love.graphics.setColor(1,1,1,1)
                love.graphics.setShader()
            end

            if tile > 500 then                                      --Draw tree
                local time = love.timer.getTime()
                local sway = math.sin(time + yC) * 0.04

                love.graphics.setShader(spriteShader)
                spriteShader:send("divideBy", 1.5)
                spriteShader:send("angle", angle)   
                spriteShader:send("objectCanvas", colorMapCanvas)
                spriteShader:send("spriteLeftX", xTileWidthOffsetX * scaleX + 32/2 * scaleX - 480/2 * scaleX)    
                spriteShader:send("spriteTopY", yTileHeightOffsetY * scaleY - 224*scaleY)
                spriteShader:send("spriteHeight",480.0*scaleX)
                spriteShader:send("spriteWidth",960.0*scaleY)
                spriteShader:send("spriteBase", 250*scaleY)
                spriteShader:send("xstart", 193*scaleX)
                spriteShader:send("xend", 320*scaleX)
                spriteShader:send("shadowSize", 70*scaleX)
        
                love.graphics.setCanvas(shadowCanvas)
                love.graphics.draw(             --Draw the trunk shadow
                    treeSheet,
                    treeTrunk,
                    xTileWidthOffsetX * scaleX,
                    yTileHeightOffsetY * scaleY,
                    sway,
                    scaleX,
                    scaleY,
                    224,
                    224        
                )

                spriteShader:send("shadowSize", 150*scaleX)
                spriteShader:send("xstart",150*scaleX)
                spriteShader:send("xend",350*scaleX)
                love.graphics.setCanvas(shadowCanvas)
                love.graphics.draw(             --Draw the tree leaves shadow
                    treeSheet,
                    treeFoliage,
                    xTileWidthOffsetX * scaleX,
                    yTileHeightOffsetY * scaleY,
                    sway,
                    scaleX,
                    scaleY,
                    224,
                    224        
                )

        
                love.graphics.setShader()
                love.graphics.setCanvas(objectCanvas)
                love.graphics.draw(             --Draw the trunk
                    treeSheet,
                    treeTrunk,
                    xTileWidthOffsetX * scaleX,-- - 224 * scaleX,
                    yTileHeightOffsetY * scaleY,-- - 224 * scaleY,
                    sway,
                    scaleX,
                    scaleY,
                    224,
                    224        
                )       
                combinedShader:send("hueAdjust", ((xC * yC) % 45 * -1) + 22)
                combinedShader:send("time", time)
                love.graphics.setShader(combinedShader)  
                love.graphics.draw(             --Draw the tree leaves 
                    treeSheet,
                    treeFoliage,
                    xTileWidthOffsetX * scaleX + 5*scaleX,
                    yTileHeightOffsetY * scaleY,
                    sway,
                    scaleX,
                    scaleY,
                    224,
                    224        
                )
                love.graphics.setShader()
                love.graphics.setCanvas()       

            end

            if yC - 1 < 1 or yC - 1 > #mapArray then goto continueX end
            if xC < 1 or xC > #mapArray[yC - 1] then goto continueX end
            local tile = mapArray[yC - 1][xC][1]
            local yTileHeightOffsetY = (y-2)*tileSize - offsetY;
            if tile == 10 then
                love.graphics.setCanvas(objectCanvas)
                local time = love.timer.getTime()
                local windEffect = math.sin(time + yC) * 0.1
                local xAdjustment = windEffect * 27 -- 27 is the grassHeight
                love.graphics.draw(
                    grassSheet,
                    grassQuad,
                    (xTileWidthOffsetX - xAdjustment-5) * scaleX,
                    (yTileHeightOffsetY - 5) * scaleY,
                    0,
                    scaleX,
                    scaleY,
                    0, 0,
                    windEffect, 0
                )
                windEffect = math.sin(time + yC + 3) * 0.1
                xAdjustment = windEffect * 27 -- 27 is the grassHeight
                love.graphics.draw(
                    grassSheet,
                    grassQuad,
                    (xTileWidthOffsetX - xAdjustment) * scaleX,
                    (yTileHeightOffsetY + 8) * scaleY,
                    0,
                    scaleX,
                    scaleY,
                    0, 0,
                    windEffect, 0
                )
                love.graphics.setCanvas()
            end

            ::continueX::
        end

        local characterRow = math.floor(playerY / tileSize) + 1; --Plus 1 because lua doesn't have the map array start with 0. 
        if characterRow ~= yC then goto continueY end; 
        
        local characterScreenX = playerX - cameraX;
        local characterScreenY = playerY - cameraY;
    
        local spriteNumber = 1

        love.graphics.setCanvas(tempCanvas)
        love.graphics.clear()
        love.graphics.draw(
            heroSheet,
            heroQuads[spriteNumber],
            200*scaleX/2 - 112*scaleX/2,              --Center the sprite on the canvas
            200*scaleY/2 - 112*scaleY/2,              --Center the sprite on the canvas
            0,
            scaleX,
            scaleY
        )

        love.graphics.setShader(spriteShader)
        spriteShader:send("angle", angle)   
        spriteShader:send("objectCanvas", colorMapCanvas)
        spriteShader:send("spriteLeftX", characterScreenX * scaleX + 32/2 * scaleX - 200/2 * scaleX)    
        spriteShader:send("spriteTopY", characterScreenY * scaleY - 128*scaleY)
        spriteShader:send("spriteHeight",200.0*scaleX)
        spriteShader:send("spriteWidth",200.0*scaleY)
        spriteShader:send("spriteBase", ((200-112)/2+80)*scaleY)
        spriteShader:send("xstart", ((200-112)/2+43)*scaleX)
        spriteShader:send("xend", ((200-112)/2+71)*scaleX)
        spriteShader:send("shadowSize", 70.0*scaleX)
        spriteShader:send("divideBy", 1.0)

        love.graphics.setCanvas(shadowCanvas)
        love.graphics.draw(
            tempCanvas,
            characterScreenX * scaleX + 32/2 * scaleX - 200/2 * scaleX,
            characterScreenY * scaleY - 128*scaleY       --128 = base + (200-112)/2 
        )

        love.graphics.setShader()
        
        love.graphics.setCanvas(objectCanvas)
        love.graphics.draw(
            tempCanvas,
            characterScreenX * scaleX + 32/2 * scaleX - 200/2 * scaleX,
            characterScreenY * scaleY - 128*scaleY       --128 = base + (200-112)/2 
        )
        love.graphics.setCanvas()
        ::continueY::
    end

    love.graphics.setColor(2,2,2,.2)
    love.graphics.setBlendMode("multiply", "premultiplied")
    love.graphics.draw(
        grunge,
        cameraX * scaleX * -1,
        cameraY * scaleY * -1,
        0,
        scaleX * 2,
        scaleY * 2
    )
    love.graphics.setBlendMode("alpha")
    
    love.graphics.setColor(1,1,1,1)
    --love.graphics.draw(colorMapCanvas, 0, 0)
    love.graphics.setCanvas(shadowCanvas)
    love.graphics.setShader(shadowShader)
    shadowShader:send("angle", angle)
    shadowShader:send("shadowSize", 32)
    shadowShader:send("objectCanvas", colorMapCanvas) 
    love.graphics.draw(colorMapCanvas)
    love.graphics.setShader()
    love.graphics.setCanvas()
    if showColorMap == true then love.graphics.draw(colorMapCanvas) end
    love.graphics.setColor(1,1,1,0.4)
    love.graphics.draw(shadowCanvas, 0, 0)
    love.graphics.setColor(1,1,1,1)
    love.graphics.draw(objectCanvas, 0, 0)

    love.graphics.print("Tiles Horizontal: " .. tilesHorizontal, 10, 10)
    love.graphics.print("Tiles Vertical: " .. tilesVertical, 10, 30)
    love.graphics.print("Tilesize vertical is " .. spriteSheet:getHeight() / tileSize, 10, 50)
    love.graphics.print("Tilesize horizontal is " .. spriteSheet:getWidth() / tileSize, 10, 70)
    love.graphics.print("Player X: " .. playerX, 10, 90)
    love.graphics.print("Player Y: " .. playerY, 10, 110)   
    love.graphics.print("The number of sprites is " .. #sprites, 10, 130)
    love.graphics.print("The zoom value is " .. scaleX, 10, 150)
    love.graphics.print("The angle is " .. angle, 10, 170)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 190)

end

function prng(seed)
    local a = 1103515245
    local c = 12345
    local m = 2^31
    seed = ( a * seed + c) % m
    return seed / m
end