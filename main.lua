
local appWidth, appHeight
local scaleFactor, scaleOffsetX, scaleOffsetY

function love.load()
    spriteMap = require("spriteMap")
    mapArray = require("maps.map01")

    love.window.setMode(1280, 800, {resizable=true, vsync=false})
    love.window.setTitle("Scattered Verses")
    love.graphics.setDefaultFilter("nearest", "nearest")

    appWidth, appHeight = love.graphics.getDimensions()
    require("src/require")
    requireAll()

    updateDimensions()
end

function love.resize(w, h)
    appWidth, appHeight = w, h
    updateDimensions()
end

function love.keypressed(key)
    if key == "c" then
        canvas.showColorMap = not canvas.showColorMap
    elseif key == "" then
        player:keypressed(key) -- Call the player's keypressed method
    end
end

function love.keyreleased(key)
    player:keyreleased(key) -- Call the player's keyreleased method
end

function love.update(dt)
    player:update(dt)
    shadow:update(dt)

    -- Handle quitting the game
    if love.keyboard.isDown('escape') then
        love.event.quit()
    end
    if love.keyboard.isDown('z') then
        window.width = window.width - 8         --It's got to be 8 otherwise sprite zooming looks wonky
        window.height = window.height - 8
        if window.width <=400 then window.width = 400 end
        if window.height <=400 then window.height = 400 end
        canvas:initialize(window.width, window.height)
        updateDimensions()
    end
    if love.keyboard.isDown('x') then
        window.width = window.width + 8
        window.height = window.height + 8
        if window.width >=800 then window.width = 800 end
        if window.height >=800 then window.height = 800 end
        canvas:initialize(window.width, window.height)
        updateDimensions()
    end
end


function love.draw()
    -- Clear the canvas before each frame
    canvas.clear()
    sprites.tileBatch:clear()
    shadow:check()

    -- Calculate the number of tiles
    local tilesHorizontal = math.ceil(window.width / sprites.size)
    local tilesVertical = math.ceil(window.height / sprites.size)

    -- Camera positioning
    local cameraX = player.x - window.width / 2
    local cameraY = player.y - window.height / 2

    -- Determine the first tile to draw
    local firstTileX = math.floor(cameraX / sprites.size)
    local firstTileY = math.floor(cameraY / sprites.size)
    local offsetX = cameraX % sprites.size
    local offsetY = cameraY % sprites.size

    -- Iterate through visible tiles and add them to the tile batch
    for y = 0, tilesVertical + 5 do
        local yC = firstTileY + y
        if yC < 1 or yC > #mapArray then goto continueY end
        for x = -10, tilesHorizontal + 5 do
            local xC = firstTileX + x
            if xC < 1 or xC > #mapArray[yC] then goto continueX end
            local xTileOffset = (x - 1) * sprites.size - offsetX
            local yTileOffset = (y - 1) * sprites.size - offsetY
            local tile, z = mapArray[yC][xC][1], mapArray[yC][xC][2]
            local zHeight = z / sprites.size    -- Calculate the z height of the tile in tiles (32 x 32)

            if tile == 1 then                   -- Grass tile
                grass:add(xC, yC, z, zHeight, xTileOffset, yTileOffset)
                grass:addFlourish(xC, yC, z, zHeight, xTileOffset, yTileOffset)
                if z ~= 0 then
                    mountain:add(xC, yC, z, zHeight, xTileOffset, yTileOffset)
                end
            end
            if tile == 10 then
                grass:add(xC, yC, z, zHeight, xTileOffset, yTileOffset)
                tallGrass:add(xC, yC, z, zHeight, xTileOffset, yTileOffset, cameraY)
            end
            if tile == 512 then
                grass:add(xC, yC, z, zHeight, xTileOffset, yTileOffset)
                tree:add(xC, yC, z, zHeight, xTileOffset, yTileOffset, cameraX, cameraY)
            end
            ::continueX::
        end

        --We begin to draw the 
        local characterRow = math.floor(player.y / sprites.size) + 1
        if characterRow ~= yC then goto continueY end

        player:draw(cameraX, cameraY)

        ::continueY::
    end

    local lutNew = 96
    local lutOld = 0
    local normalizedAngle = shadow.angle % 360 / 80
    if (shadow.angle % 360 >= 0 and shadow.angle % 360 <=80) then
        normalizedAngle = shadow.angle % 360 / 80.0;
        lutNew = 96.0;
        lutOld = 0;
    elseif (shadow.angle % 360 >= 80 and shadow.angle % 360 <=100) then
        normalizedAngle = shadow.angle % 360 / 90.0
        lutNew = 0
        lutOld = 0
    elseif (shadow.angle % 360 > 100 and shadow.angle % 360 <=180 ) then
        normalizedAngle = (shadow.angle % 360 - 100.0) / 80.0
        lutNew = 0
        lutOld = 32.0
    elseif (shadow.angle % 360 > 180 and shadow.angle % 360 <=260) then
        normalizedAngle = (shadow.angle % 360 - 180.0) / 80.0
        lutNew = 32.0
        lutOld = 63.0
    elseif (shadow.angle % 360 > 260 and shadow.angle % 360 <=280) then
        normalizedAngle = (shadow.angle % 360 - 180.0) / 90.0
        lutNew = 63.0
        lutOld = 63.0
    elseif (shadow.angle % 360 > 280 and shadow.angle % 360 <=360) then
        normalizedAngle = (shadow.angle % 360 - 280.0) / 80.0
        lutNew = 63.0
        lutOld = 96.0
    end

    -- Draw to the offscreen canvas (grass, dirt, first layer stuff, etc.)
    love.graphics.setCanvas(canvas.offscreen)
    love.graphics.draw(sprites.tileBatch)
    if canvas.showColorMap then love.graphics.draw(canvas.colorMap) end


    -- Draw everything else (objects, their shadows, and occluder shadows)
    love.graphics.setCanvas(canvas.intermediate)
    shader.ultimate:send("objectCanvas", canvas.object)
    shader.ultimate:send("shadowCanvas", canvas.shadow)
    shader.ultimate:send("colorMapCanvas", canvas.colorMap)
    shader.ultimate:send("lutImage", sprites.lut)
    shader.ultimate:send("shadowAngle", shadow.angle)
    shader.ultimate:send("shadowSize", shadow.size)
    shader.ultimate:send("shadowAlpha", 0.5 * (1 - math.abs((shadow.angle - 360) % 360 -90)/90))
    shader.ultimate:send("lutOld", lutOld)
    shader.ultimate:send("lutNew", lutNew)
    shader.ultimate:send("spotlight", {player.x + 8 - cameraX, player.y - cameraY + player.z/2})
    shader.ultimate:send("canvasSize", {window.width, window.height})
    shader.ultimate:send("normalizedAngle", normalizedAngle)
    love.graphics.setShader(shader.ultimate)
    love.graphics.draw(canvas.offscreen, 0, 0, 0, 1, 1)

    love.graphics.setCanvas() -- Reset to default screen rendering
    love.graphics.setShader()

    -- Draw the offscreen canvas, scaling it and centering it on the screen
    love.graphics.draw(canvas.intermediate, scaleOffsetX, scaleOffsetY, 0, scaleFactor, scaleFactor)

    love.graphics.setColor(1,1,1,1)
    love.graphics.setFont(love.graphics.newFont(12))
    love.graphics.print("Window Width: " .. window.width, 10, 10)
    love.graphics.print("Window Height: " .. window.height, 10, 30)
    love.graphics.print("appWidth:  " .. appWidth, 10, 50)
    love.graphics.print("appHeight: " .. appHeight, 10, 70)
    love.graphics.print("scaleX: " .. appWidth / window.width, 10, 90)
    love.graphics.print("scaleY: " .. appHeight / window.height, 10, 110)
    love.graphics.print("scaleFactor: " ..scaleFactor, 10, 130)
    love.graphics.setFont(love.graphics.newFont(32))
    love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 150) 

end

function updateDimensions()

    local scaleX = appWidth / window.width
    local scaleY = appHeight / window.height

    scaleFactor = math.max(scaleX, scaleY)

    scaleOffsetX = (appWidth - (window.width * scaleFactor)) / 2  
    scaleOffsetY = (appHeight - (window.height * scaleFactor)) / 2

    shadow.frame = 0 --Make sure we adjust shadows for zoom
end






