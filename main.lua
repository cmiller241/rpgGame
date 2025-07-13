local appWidth, appHeight
local scaleFactor, scaleOffsetX, scaleOffsetY
local accumulator = 0 -- For fixed time-step
local alpha = 0 -- For interpolation

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
    else
        player:keypressed(key)
    end
end

function love.keyreleased(key)
    player:keyreleased(key)
end

function love.update(dt)
    local fixedDt = 1 / 60
    accumulator = accumulator + dt

    while accumulator >= fixedDt do
        player:update(fixedDt)
        shadow:update(fixedDt)
        accumulator = accumulator - fixedDt
    end
    alpha = accumulator / fixedDt

    if love.keyboard.isDown('escape') then
        love.event.quit()
    end
    if love.keyboard.isDown('z') then
        window.width = window.width - 8
        window.height = window.height - 8
        if window.width <= 400 then window.width = 400 end
        if window.height <= 400 then window.height = 400 end
        canvas:initialize(window.width, window.height)
        updateDimensions()
    end
    if love.keyboard.isDown('x') then
        window.width = window.width + 8
        window.height = window.height + 8
        if window.width >= 1000 then window.width = 1000 end
        if window.height >= 1000 then window.height = 1000 end
        canvas:initialize(window.width, window.height)
        updateDimensions()
    end
    if love.keyboard.isDown('m') then
        shadow.angle = shadow.angle + shadow.rotationSpeed * fixedDt
    end
    if love.keyboard.isDown('n') then
        shadow.angle = shadow.angle - shadow.rotationSpeed * fixedDt
        if shadow.angle < 0 then shadow.angle = 0 end
    end
end

function love.draw()
    canvas.clear()
    sprites.tileBatch:clear()
    sprites.treeBatch:clear()
    sprites.treeShadowBatch:clear()
    love.graphics.setCanvas(canvas.shadow)
    love.graphics.clear(0,0,0,0)

    local tilesHorizontal = math.ceil(window.width / sprites.size)
    local tilesVertical = math.ceil(window.height / sprites.size)
    local cameraX = player.x - window.width / 2
    local cameraY = player.y - window.height / 2
    local firstTileX = math.floor(cameraX / sprites.size)
    local firstTileY = math.floor(cameraY / sprites.size)
    local offsetX = cameraX % sprites.size
    local offsetY = cameraY % sprites.size

    for y = 0, tilesVertical + 5 do
        local yC = firstTileY + y
        if yC < 1 or yC > #mapArray then goto continueY end
        for x = -5, tilesHorizontal + 5 do
            local xC = firstTileX + x
            if xC < 1 or xC > #mapArray[yC] then goto continueX end
            local xTileOffset = (x - 1) * sprites.size - offsetX
            local yTileOffset = (y - 1) * sprites.size - offsetY
            local tile, z = mapArray[yC][xC][1], mapArray[yC][xC][2]
            local zHeight = z / sprites.size

            if tile == 1 then
                grass:add(xC, yC, z, zHeight, xTileOffset, yTileOffset)
                grass:addFlourish(xC, yC, z, zHeight, xTileOffset, yTileOffset)
                if z ~= 0 then
                    if sprites.treeBatch:getCount() > 0 then
                        love.graphics.setCanvas(canvas.object)
                        love.graphics.draw(sprites.treeBatch)
                        sprites.treeBatch:clear()
                    end
                    if shadow.frame == shadow.frequency and sprites.treeShadowBatch:getCount() > 0 then
                        love.graphics.setCanvas(canvas.shadow)
                        love.graphics.setShader(shader.sprite)
                        love.graphics.setBlendMode('lighten', 'premultiplied')
                        shader.sprite:send("divideBy", 2)
                        shader.sprite:send("angle", shadow.angle)
                        shader.sprite:send("colorMapCanvas", canvas.colorMap)
                        shader.sprite:send("spriteHeight", 480.0)
                        shader.sprite:send("spriteWidth", 1440.0)
                        shader.sprite:send("spriteBase", 250)
                        shader.sprite:send("xstart", 100)
                        shader.sprite:send("xend", 320)
                        shader.sprite:send("shadowSize", 250)
                        shader.sprite:send("opacity", 1.0)
                        shader.sprite:send("canvasSize", {800, 600})
                        shader.sprite:send("spotlight", {player.x + 8 - cameraX, player.y - cameraY + player.z / 2})
                        if (shadow.angle % 360 > 180 and shadow.angle % 360 < 360) then
                            shader.sprite:send("noSunShadows", 1.0)
                        else
                            shader.sprite:send("noSunShadows", 0.0)
                        end
                        shader.sprite:send("showSpotlight", 1)
                        love.graphics.draw(sprites.treeShadowBatch)
                        love.graphics.setBlendMode('alpha')
                        love.graphics.setShader()
                        sprites.treeShadowBatch:clear()
                    end
                    mountain:add(xC, yC, z, zHeight, xTileOffset, yTileOffset)
                end
            elseif tile == 10 then
                grass:add(xC, yC, z, zHeight, xTileOffset, yTileOffset)
                tallGrass:add(xC, yC, z, zHeight, xTileOffset, yTileOffset, cameraX, cameraY)
            elseif tile == 512 then
                grass:add(xC, yC, z, zHeight, xTileOffset, yTileOffset)
                tree:add(xC, yC, z, zHeight, xTileOffset, yTileOffset, cameraX, cameraY)
            end
            ::continueX::
        end

        local characterRow = math.floor(player.y / sprites.size) + 1
        if characterRow == yC then
            player:draw(cameraX, cameraY, alpha)
        end
        ::continueY::
    end

    if sprites.treeBatch:getCount() > 0 then
        love.graphics.setCanvas(canvas.object)
        love.graphics.draw(sprites.treeBatch)
        sprites.treeBatch:clear()
    end
    if shadow.frame == shadow.frequency and sprites.treeShadowBatch:getCount() > 0 then
        love.graphics.setCanvas(canvas.shadow)
        love.graphics.setShader(shader.sprite)
        love.graphics.setBlendMode('lighten', 'premultiplied')
        shader.sprite:send("divideBy", 2)
        shader.sprite:send("angle", shadow.angle)
        shader.sprite:send("colorMapCanvas", canvas.colorMap)
        shader.sprite:send("spriteHeight", 480.0)
        shader.sprite:send("spriteWidth", 1440.0)
        shader.sprite:send("spriteBase", 250)
        shader.sprite:send("xstart", 100)
        shader.sprite:send("xend", 320)
        shader.sprite:send("shadowSize", 250)
        shader.sprite:send("opacity", 1.0)
        shader.sprite:send("canvasSize", {800, 600})
        shader.sprite:send("spotlight", {player.x + 8 - cameraX, player.y - cameraY + player.z / 2})
        if (shadow.angle % 360 > 180 and shadow.angle % 360 < 360) then
            shader.sprite:send("noSunShadows", 1.0)
        else
            shader.sprite:send("noSunShadows", 0.0)
        end
        shader.sprite:send("showSpotlight", 1)
        love.graphics.draw(sprites.treeShadowBatch)
        love.graphics.setBlendMode('alpha')
        love.graphics.setShader()
        sprites.treeShadowBatch:clear()
    end

    local lutNew = 96
    local lutOld = 0
    local normalizedAngle = shadow.angle % 360 / 80
    if (shadow.angle % 360 >= 0 and shadow.angle % 360 <= 80) then
        normalizedAngle = shadow.angle % 360 / 80.0
        lutNew = 96.0
        lutOld = 0
    elseif (shadow.angle % 360 >= 80 and shadow.angle % 360 <= 100) then
        normalizedAngle = shadow.angle % 360 / 90.0
        lutNew = 0
        lutOld = 0
    elseif (shadow.angle % 360 > 100 and shadow.angle % 360 <= 180) then
        normalizedAngle = (shadow.angle % 360 - 100.0) / 80.0
        lutNew = 0
        lutOld = 32.0
    elseif (shadow.angle % 360 > 180 and shadow.angle % 360 <= 260) then
        normalizedAngle = (shadow.angle % 360 - 180.0) / 80.0
        lutNew = 32.0
        lutOld = 63.0
    elseif (shadow.angle % 360 > 260 and shadow.angle % 360 <= 280) then
        normalizedAngle = (shadow.angle % 360 - 180.0) / 90.0
        lutNew = 63.0
        lutOld = 63.0
    elseif (shadow.angle % 360 > 280 and shadow.angle % 360 <= 360) then
        normalizedAngle = (shadow.angle % 360 - 280.0) / 80.0
        lutNew = 63.0
        lutOld = 96.0
    end

    love.graphics.setCanvas(canvas.offscreen)
    love.graphics.draw(sprites.tileBatch)
    if canvas.showColorMap then
        love.graphics.draw(canvas.colorMap)
    end

    love.graphics.setCanvas(canvas.intermediate)
    shader.ultimate:send("objectCanvas", canvas.object)
    shader.ultimate:send("shadowCanvas", canvas.shadow)
    shader.ultimate:send("colorMapCanvas", canvas.colorMap)
    shader.ultimate:send("lutImage", sprites.lut)
    shader.ultimate:send("shadowAngle", shadow.angle)
    shader.ultimate:send("shadowSize", shadow.size)
    shader.ultimate:send("shadowAlpha", 0.5 * (1 - math.abs((shadow.angle - 360) % 360 - 90) / 90)^2)    shader.ultimate:send("lutOld", lutOld)
    shader.ultimate:send("lutNew", lutNew)
    shader.ultimate:send("spotlight", {player.x + 8 - cameraX, player.y - cameraY + player.z / 2})
    shader.ultimate:send("canvasSize", {window.width, window.height})
    shader.ultimate:send("normalizedAngle", normalizedAngle)
    love.graphics.setShader(shader.ultimate)
    love.graphics.draw(canvas.offscreen, 0, 0, 0, 1, 1)

    love.graphics.setCanvas()
    love.graphics.setShader()
    love.graphics.draw(canvas.intermediate, scaleOffsetX, scaleOffsetY, 0, scaleFactor, scaleFactor)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(12))
    love.graphics.print("Player Z: " .. player.z, 10, 10)
    love.graphics.print("Player VZ: " .. player.vz, 10, 30)
    love.graphics.print("IsOnGround: " .. tostring(player.isOnGround), 10, 50)
    love.graphics.print("Player Jump: " .. tostring(player.jump), 10, 70)
    love.graphics.print("Shadow Angle: " .. shadow.angle, 10, 90)
    love.graphics.setFont(love.graphics.newFont(32))
    love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 150)
    local stats = love.graphics.getStats()
    love.graphics.print("Draw Calls: " .. stats.drawcalls, 10, 170)
    love.graphics.print("Canvas Switches: " .. stats.canvasswitches, 10, 190)
end

function updateDimensions()
    local scaleX = appWidth / window.width
    local scaleY = appHeight / window.height
    scaleFactor = math.max(scaleX, scaleY)
    scaleOffsetX = (appWidth - (window.width * scaleFactor)) / 2
    scaleOffsetY = (appHeight - (window.height * scaleFactor)) / 2
    shadow.frame = 0
end