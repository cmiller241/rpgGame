local scaleX = 3
local scaleY = 3
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
local leavesShader = love.graphics.newShader[[
    extern number time;
    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
        vec2 displacement = vec2(sin(texture_coords.y * 10.0 + time) * 0.005, 0.0);
        vec4 pixel = Texel(texture, texture_coords + displacement);
        return pixel * color;
    }
]]
local leafShader = love.graphics.newShader[[
    extern number time;

    vec4 position(mat4 transform_projection, vec4 vertex_position) {
        vertex_position.x += sin(vertex_position.y / 100.0 + time) * 10.0;
        return transform_projection * vertex_position;
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

function love.load()
    love.window.setMode(1280, 800, {resizable=true, vsync=false, minwidth=400, minheight=300})
    love.window.setTitle("RPG")
    love.graphics.setDefaultFilter("nearest", "nearest")

    mapArray = require("maps.map01");

    spriteSheet = love.graphics.newImage("img/sprites2.png")
    grassSheet = love.graphics.newImage("img/grass.png")
    heroSheet = love.graphics.newImage("img/sprites-fixedgrid.png")    
    treeSheet = love.graphics.newImage("img/tree.png")

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
    
    --Create quads for tree
    grassQuad = love.graphics.newQuad(128, 0, 32, 27, grassSheet:getDimensions())
    treeTrunk = love.graphics.newQuad(0, 0, 160, 224, treeSheet:getDimensions())
    treeFoliage = love.graphics.newQuad(160,0,160,160, treeSheet:getDimensions())
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

end

function love.draw()
    
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
    
    for y = 1, tilesVertical + 10 do                             --+5 because of the damn trees. 
        local yC = firstTileY + y
        if yC < 1 then goto continueY end
        for x = -1, tilesHorizontal + 3 do
            local xC = firstTileX + x
            if xC < 1 then goto continueX end
            local xTileWidthOffsetX = (x-1)*tileSize - offsetX;
            local yTileHeightOffsetY = (y-1)*tileSize - offsetY;

            local tile = mapArray[yC][xC][1]

            if tile == 1 or tile == 10 or tile > 500 then                         --Draw grass    
                tempTile = 8 
                love.graphics.draw(
                    spriteSheet, 
                    sprites[tempTile], 
                    xTileWidthOffsetX * scaleX,
                    yTileHeightOffsetY * scaleY,
                    0, 
                    scaleX, 
                    scaleY
                )
            end

            if tile == 1 then
                local hash = math.floor((yC * xC) % 12 + 11);
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
                    yTileHeightOffsetY * scaleY,
                    0,
                    scaleX,
                    scaleY
                )
            end

            if tile > 500 then                                      --Draw tree
                love.graphics.draw(                                 --Draw tree trunk
                    treeSheet,
                    treeTrunk,
                    xTileWidthOffsetX * scaleX - 64*scaleX,
                    yTileHeightOffsetY * scaleY - 192*scaleY,
                    0,
                    scaleX,
                    scaleY
                )
                leavesShader:send('time', love.timer.getTime())
                --leafShader:send('imgHeight', 160)
                --leafShader:send('hue', (xC + yC) % 360)
                love.graphics.setShader(leavesShader)
                love.graphics.draw(                                 --Draw tree foliage
                    treeSheet,
                    treeFoliage,
                    xTileWidthOffsetX * scaleX - 64*scaleX,
                    yTileHeightOffsetY * scaleY - 192*scaleY,
                    0,
                    scaleX,
                    scaleY
                )
                love.graphics.setShader()
            end

            if yC - 1 < 1 then goto continueX end
            local tile = mapArray[yC - 1][xC][1]
            local yTileHeightOffsetY = (y-2)*tileSize - offsetY;
            if tile == 10 then
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
            end

            ::continueX::
        end

        local characterRow = math.floor(playerY / tileSize) + 1; --Plus 1 because lua doesn't have the map array start with 0. 
        if characterRow ~= yC then goto continueY end; 
        
        local characterScreenX = playerX - cameraX;
        local characterScreenY = playerY - cameraY;
    
        local spriteNumber = 1

        -- Color the shadow sprite black and reduce its opacity
        love.graphics.setColor(0, 0, 0, 0.2)

        local lightSourceX  = 500
        local lightSourceY  = 500
        local dx            = lightSourceX - playerX
        local dy            = lightSourceY - playerY
        local distance      = math.sqrt(dx^2 + dy^2) / 400
        local angle         = math.atan2(dy, dx)
        local shearing      = distance * math.cos(angle) 
		local shadowScaleY  = distance * math.sin(angle) 

        --local qx, qy, qw, qh = heroQuads[spriteNumber]:getViewport()
        --local newQuad = love.graphics.newQuad(qx, qy, qw, 84, heroSheet:getDimensions())

        love.graphics.draw(
            heroSheet,
            heroQuads[spriteNumber],
            characterScreenX * scaleX + 32/2 * scaleX,
            characterScreenY * scaleY,       --84 is base of the character.   
            0,
            scaleX,
            shadowScaleY, 
            112/2, 
            84,
            shearing,
            0
        )

        -- -- Draw the shadow sprite with a shear transformation
        -- local time = love.timer.getTime()
        -- local shearFactor = math.sin(time) * 0.5
        -- local adjustment = shearFactor * 84 * scaleY

        -- love.graphics.draw(
        --     heroSheet, 
        --     heroQuads[spriteNumber], 
        --     characterScreenX * scaleX + 32/2 * scaleX - 112/2 * scaleX - adjustment,
        --     characterScreenY * scaleY - 84*scaleY + 120,       --84 is base of the character.    
        --     0, 
        --     scaleX, 
        --     scaleY/2,
        --     0, 0, -- origin offset (ox, oy)
        --     shearFactor, 0 -- shear factors (kx, ky)
        -- )

        -- Draw the sprite
        love.graphics.setColor(1, 1, 1, 1)  -- Set the color back to opaque white
        love.graphics.draw(
            heroSheet, 
            heroQuads[spriteNumber], 
            characterScreenX * scaleX + 32/2 * scaleX - 112/2 * scaleX,
            characterScreenY * scaleY - 84*scaleY,       --84 is base of the character.    
            0, 
            scaleX, 
            scaleY
        )
        ::continueY::
    end

    love.graphics.print("Tiles Horizontal: " .. tilesHorizontal, 10, 10)
    love.graphics.print("Tiles Vertical: " .. tilesVertical, 10, 30)
    love.graphics.print("Tilesize vertical is " .. spriteSheet:getHeight() / tileSize, 10, 50)
    love.graphics.print("Tilesize horizontal is " .. spriteSheet:getWidth() / tileSize, 10, 70)
    love.graphics.print("Player X: " .. playerX, 10, 90)
    love.graphics.print("Player Y: " .. playerY, 10, 110)   
    love.graphics.print("The number of sprites is " .. #sprites, 10, 130)
end
