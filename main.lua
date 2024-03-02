local scaleX = 1
local scaleY = 1
local windowX = 1300
local windowY = 360 + 32*10
local increasing = true
local playerX = 200
local playerY = 250
local playerZ = 0
local playerFriction = .96
local playerFrame = 1
local playerFrameTime = 0
local playerFrameDuration = 0.2
local playerDirection = "Down"
local playerState = "Standing"
local playerSpeed = 200
local playerZSpeed = .5
local playerJump = false
local playerJumpForce = -8
local playerIsOnGround = true
local playerSpeedLimit = 5
local playerax = 0
local playeray = 0
local playeraz = 0
local playervx = 0
local playervy = 0
local playervz = 0
local playerGravity = 30
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
local angle = 40
local shadowSize = 32
local showColorMap = false
local spriteMap = require("spriteMap")
local Character = require("character") 
local objectCanvas = love.graphics.newCanvas(windowX,windowY)
local shadowCanvas = love.graphics.newCanvas(windowX,windowY)
local colorMapCanvas = love.graphics.newCanvas(windowX,windowY)
local offscreenCanvas = love.graphics.newCanvas(windowX,windowY)
local tempCanvas = love.graphics.newCanvas(200*scaleX,200*scaleY)
local gradientShader = love.graphics.newShader("shaders/gradientShader.glsl")
local lightShader = love.graphics.newShader("shaders/lightShader.glsl")    
local brightenShader = love.graphics.newShader("shaders/brightenShader.glsl")
local combinedShader = love.graphics.newShader("shaders/combinedShader.glsl")
local leavesShader = love.graphics.newShader("shaders/leavesShader.glsl")
local grassShader = love.graphics.newShader("shaders/grassShader.glsl")
local shadowShader = love.graphics.newShader("shaders/shadowShader.glsl")
local spriteShader = love.graphics.newShader("shaders/spriteShader.glsl")


function love.load()
    love.window.setMode(1920, 1080, {resizable=true, vsync=false, minwidth=400, minheight=300})
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
    objectCanvas = love.graphics.newCanvas(windowX,windowY)
    shadowCanvas = love.graphics.newCanvas(windowX,windowY)   
    colorMapCanvas = love.graphics.newCanvas(windowX,windowY)
    offscreenCanvas = love.graphics.newCanvas(windowX,windowY)
    tempCanvas = love.graphics.newCanvas(200*scaleX,200*scaleY)
end

function love.keypressed(key)
    if key == "c" then
        showColorMap = not showColorMap
    end
end

function love.keyreleased(key)
    if key == "space" then
        if (playerJump == false and playerIsOnGround == true) then playerJump = true end
    end
end

function love.update(dt)
    local previousState = playerState
    local previousDirection = playerDirection

    playerFrameTime = playerFrameTime + dt

    if playerFrameTime >= playerFrameDuration then
        playerFrame = playerFrame + 1
        playerFrameTime = 0

        local numFrames = #spriteMap["Cody"][playerState][playerDirection]
        if playerFrame > numFrames then playerFrame = 1 end
    end

    playerState = "Standing"

    if love.keyboard.isDown("right") then
        playerax = 1
        playerState = "Walking"
        playerDirection = "Right"
    end
    if love.keyboard.isDown("left") then
        playerax = -1
        playerState = "Walking"
        playerDirection = "Left"
    end
    if love.keyboard.isDown("up") then
        playeray = -1
        playerState = "Walking"
        playerDirection = "Up"
    end
    if love.keyboard.isDown("down") then
        --playerY = playerY + playerSpeed * dt
        playeray = 1
        playerState = "Walking"
        playerDirection = "Down"
    end
    if not love.keyboard.isDown("right") and not love.keyboard.isDown("left") then
        playerax = 0
        playervx = 0
    end
    if not love.keyboard.isDown("up") and not love.keyboard.isDown("down") then
        playeray = 0
        playervy = 0
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
    if love.keyboard.isDown('escape') then
        love.event.quit()
    end
    if playerIsOnGround == false then 
        if playervz < 0 then playerState = "Jumping-Up" end
        if playervz > 0 then playerState = "Jumping-Down" end
    end

    playerJumpForce = -20
    if playerJump == true and playerIsOnGround == true then
        playervz = playerJumpForce
        playerIsOnGround = false
        playerJump = false
    end

    playerGravity = 0.08 
    local speedFactor = 20.0
    local gravityFactor = 500
    --playervz = playervz + playeraz
    playervz = playervz + playerGravity * gravityFactor * dt
    playerZ = playerZ + playervz * speedFactor * dt

    playervx = (playervx + playerax) * playerFriction
    playervy = (playervy + playeray) * playerFriction

    if playervx < -1 * playerSpeedLimit then playervx = -1 * playerSpeedLimit end
    if playervx > playerSpeedLimit then playervx = playerSpeedLimit end
    if playervy < -1 * playerSpeedLimit then playervy = -1 * playerSpeedLimit end
    if playervy > playerSpeedLimit then playervy = playerSpeedLimit end 
    --moveCharacter(playervx, playervy, playervz)

    if playerZ > 0 then 
        playerZ = 0
        playerIsOnGround = true
    end

    if playerState ~= previousState or playerDirection ~= previousDirection then
        playerFrame = 1
        playerFrameTime = 0
    end

end


function love.draw()
    love.graphics.setCanvas()
    love.graphics.clear()
    love.graphics.setCanvas(objectCanvas)
    love.graphics.clear()
    love.graphics.setCanvas(shadowCanvas)
    love.graphics.clear()
    love.graphics.setCanvas(colorMapCanvas)
    love.graphics.clear()
    love.graphics.setCanvas(offscreenCanvas)
    love.graphics.clear()

    --local windowWidth, windowHeight = love.graphics.getDimensions()
    local windowWidth = windowX
    local windowHeight = windowY
    local tilesHorizontal = math.ceil(windowWidth / (tileSize * scaleX))
    local tilesVertical = math.ceil(windowHeight / (tileSize * scaleY))

    local cameraX = playerX - windowWidth / 2 
    local cameraY = playerY - windowHeight / 2 
    if cameraX < 0 then cameraX = 0 end
    if cameraY < 0 then cameraY = 0 end 

    local firstTileX = math.floor(cameraX / tileSize)
    local firstTileY = math.floor(cameraY / tileSize)
    local offsetX = cameraX % tileSize
    local offsetY = cameraY % tileSize 
    
    for y = 1, tilesVertical+5 do                             --+10 because of the damn trees. 
        local yC = firstTileY + y
        if yC < 1 or yC > #mapArray then goto continueY end
        for x = 1, tilesHorizontal+5 do                          --+5 because of the damn trees.
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
                    love.graphics.setCanvas(offscreenCanvas)
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
                    love.graphics.setCanvas(offscreenCanvas)
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

                    love.graphics.setCanvas(offscreenCanvas)--(objectCanvas)
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
                    
                    love.graphics.setCanvas(offscreenCanvas)
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
                spriteShader:send("divideBy", 1)
                spriteShader:send("angle", angle)   
                spriteShader:send("objectCanvas", colorMapCanvas)
                spriteShader:send("spriteLeftX", xTileWidthOffsetX * scaleX + 32/2 * scaleX - 480/2 * scaleX)    
                spriteShader:send("spriteTopY", yTileHeightOffsetY * scaleY - 224*scaleY)
                spriteShader:send("spriteHeight",480.0*scaleX)
                spriteShader:send("spriteWidth",960.0*scaleY)
                spriteShader:send("spriteBase", 250*scaleY)
                spriteShader:send("xstart", 193*scaleX)
                spriteShader:send("xend", 320*scaleX)
                spriteShader:send("shadowSize", 140)
                spriteShader:send("opacity", 1.0)
                spriteShader:send("canvasSize", {windowX, windowY})
        
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

                spriteShader:send("shadowSize", 250)
                spriteShader:send("xstart",150)
                spriteShader:send("xend",350)
                love.graphics.setCanvas(shadowCanvas)
                love.graphics.draw(             --Draw the tree leaves shadow
                    treeSheet,
                    treeFoliage,
                    xTileWidthOffsetX,
                    yTileHeightOffsetY,
                    sway,
                    1,
                    1,
                    224,
                    224        
                )

        
                love.graphics.setShader()
                love.graphics.setCanvas(objectCanvas)
                love.graphics.draw(             --Draw the trunk
                    treeSheet,
                    treeTrunk,
                    xTileWidthOffsetX,-- - 224 * scaleX,
                    yTileHeightOffsetY,-- - 224 * scaleY,
                    sway,
                    1,
                    1,
                    224,
                    224        
                )       
                combinedShader:send("hueAdjust", ((xC * yC) % 45 * -1) + 22)
                combinedShader:send("time", time)
                love.graphics.setShader(combinedShader)  
                love.graphics.draw(             --Draw the tree leaves 
                    treeSheet,
                    treeFoliage,
                    xTileWidthOffsetX + 5,
                    yTileHeightOffsetY,
                    sway,
                    1,
                    1,
                    224,
                    224        
                )
                love.graphics.setShader()
                love.graphics.setCanvas(offscreenCanvas)       

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
                    (xTileWidthOffsetX - xAdjustment-5),
                    (yTileHeightOffsetY - 5),
                    0,
                    1,
                    1,
                    0, 0,
                    windEffect, 0
                )
                windEffect = math.sin(time + yC + 3) * 0.1
                xAdjustment = windEffect * 27 -- 27 is the grassHeight
                love.graphics.draw(
                    grassSheet,
                    grassQuad,
                    (xTileWidthOffsetX - xAdjustment),
                    (yTileHeightOffsetY + 8),
                    0,
                    1,
                    1,
                    0, 0,
                    windEffect, 0
                )
                love.graphics.setCanvas(offscreenCanvas)
            end

            ::continueX::
        end

        local characterRow = math.floor(playerY / tileSize) + 1; --Plus 1 because lua doesn't have the map array start with 0. 
        if characterRow ~= yC then goto continueY end; 
        
        local characterScreenX = playerX - cameraX
        local characterScreenY = playerY - cameraY
        flipX = 1
        flipOffsetX = 0         --temporary canvas size divided by 2
        if playerDirection == "Left" then 
            flipX = -1 
            flipOffsetX = 200/2
        end
    
        local spriteNumber = spriteMap["Cody"][playerState][playerDirection][playerFrame]  

        love.graphics.setCanvas(tempCanvas)
        love.graphics.clear()
        love.graphics.draw(
            heroSheet,
            heroQuads[spriteNumber],
            200/2 - 112/2,              --Center the sprite on the canvas
            200/2 - 112/2,              --Center the sprite on the canvas
            0,
            flipX,
            1,
            flipOffsetX,
            0
        )

        love.graphics.setShader(spriteShader)
        spriteShader:send("angle", angle)   
        spriteShader:send("objectCanvas", colorMapCanvas)
        spriteShader:send("spriteLeftX", characterScreenX + 32/2 - 200/2)    
        spriteShader:send("spriteTopY", characterScreenY - 128)
        spriteShader:send("spriteHeight",200.0)
        spriteShader:send("spriteWidth",200.0)
        spriteShader:send("spriteBase", ((200-112)/2+80))
        spriteShader:send("xstart", ((200-112)/2+30)) --43
        spriteShader:send("xend", ((200-112)/2+80)) --71
        spriteShader:send("shadowSize", 70.0)
        spriteShader:send("divideBy", -1*playerZ/64 + 1)
        spriteShader:send("opacity", 1 - -1*playerZ/3/64)
        spriteShader:send("canvasSize", {windowX, windowY})

        love.graphics.setCanvas(shadowCanvas)
        love.graphics.draw(
            tempCanvas,
            characterScreenX + 32/2 - 200/2,
            characterScreenY - 128       --128 = base + (200-112)/2 
        )

        love.graphics.setShader()
        
        love.graphics.setCanvas(objectCanvas)
        love.graphics.draw(
            tempCanvas,
            characterScreenX + 32/2  - 200/2,
            characterScreenY - 128 + playerZ       --128 = base + (200-112)/2 
        )
        love.graphics.setCanvas(offscreenCanvas)
        ::continueY::
    end

    love.graphics.setCanvas(offscreenCanvas)
    love.graphics.setColor(2,2,2,.8)
    love.graphics.setBlendMode("multiply", "premultiplied")
    love.graphics.draw(
        grunge,
        cameraX * -1,
        cameraY * -1,
        0,
        1,
        1
    )
    love.graphics.setBlendMode("alpha")
    
    love.graphics.setColor(1,1,1,1)
    love.graphics.setCanvas(shadowCanvas)
    love.graphics.setShader(shadowShader)
    shadowShader:send("angle", angle)
    shadowShader:send("shadowSize", 32)
    shadowShader:send("objectCanvas", colorMapCanvas) 
    love.graphics.draw(colorMapCanvas)
    love.graphics.setShader()
    love.graphics.setCanvas(offscreenCanvas)
    if showColorMap == true then love.graphics.draw(colorMapCanvas) end
    love.graphics.setColor(1,1,1,.3)
    love.graphics.draw(shadowCanvas, 0, 0)
    love.graphics.setColor(1,1,1,1)
    love.graphics.draw(objectCanvas, 0, 0)

    love.graphics.setCanvas()

    local viewportX = 800
    local viewportY = 600
    local quadX = playerX - viewportX / 2
    local quadY = playerY - viewportY / 2
    quadX = math.max(0, math.min(quadX, windowX/2 - viewportX/2))
    quadY = math.max(0, math.min(quadY, windowY/2 - viewportY/2))
    local windowlong, windowhigh = love.graphics.getDimensions()
    local scalelong = windowlong / viewportX
    local scalehigh = windowhigh / viewportY
    local scale = scalelong

    local quad = love.graphics.newQuad(quadX, quadY, viewportX, viewportY, windowX, windowY)
    
    love.graphics.draw(offscreenCanvas,quad,0,0,0,scale,scale)


    love.graphics.print("Tiles Horizontal: " .. tilesHorizontal, 10, 10)
    love.graphics.print("Tiles Vertical: " .. tilesVertical, 10, 30)
    love.graphics.print("Tilesize vertical is " .. spriteSheet:getHeight() / tileSize, 10, 50)
    love.graphics.print("Tilesize horizontal is " .. spriteSheet:getWidth() / tileSize, 10, 70)
    love.graphics.print("Player X: " .. playerX, 10, 90)
    love.graphics.print("Player Y: " .. playerY, 10, 110)   
    love.graphics.print("Player Z: " .. playerZ, 10, 130)
    love.graphics.print("The number of sprites is " .. #sprites, 10, 150)
    love.graphics.print("The zoom value is " .. scaleX, 10, 170)
    love.graphics.print("The angle is " .. angle, 10, 190)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 210)

end

function prng(seed)
    local a = 1103515245
    local c = 12345
    local m = 2^31
    seed = ( a * seed + c) % m
    return seed / m
end

function moveCharacter(dx, dy, dz)
    local newx = math.floor(playerX + dx)
    local newy = math.floor(playerY + dy)
    local newz = math.floor(playerZ + dz)

    --local canMoveXY = canMoveTo(newx, newy, playerZ)
    --local canMoveZ = canMoveTo(playerX, playerY, newz)

    local canMoveXY = true
    local canMoveZ = true

    if canMoveXY then
        playerX = newx
        playerY = newy
    else 
        playervx = 0
        playervy = 0
    end

    if canMoveZ then
        playerZ = newz
    else
        playervz = 0
        playerIsOnGround = true
    end
end

function canMoveTo(newX, newY, newZ)
    local left = newX
    local right = newX + 32 --I need to get width of character here instead of 32
    local top = newY - 5    --I need to get the height of character feet here instead of 5
    local bottom = newY

    topLeftTile = getTile(left, top);
    topRightTile = getTile(right, top);
    bottomLeftTile = getTile(left, bottom);
    bottomRightTile = getTile(right, bottom);

    if (topLeftTile.v > 500 or topRightTile.v > 500  or bottomLeftTile.v > 500 or bottomRightTile.v > 500 or
    topLeftTile.z < newZ or topRightTile.z < newZ or bottomLeftTile.z < newZ or bottomRightTile.z < newZ) then
        return false;
    end

    print(topLeftTile.v)

    return true;
end

function getTile(x, y)
    local tileX = math.floor(x / 32)
    local tileY = math.floor(y / 32)
    return {
        v=mapArray[tileY][tileX][1],
        z=mapArray[tileY][tileX][2]
    }
end