-- main.lua
--
-- FRAME OVERVIEW (love.draw)
--   1. Surface map   terrain:drawSurfaceMap - per-pixel terrain shape for lighting
--   2. Scene         walk the visible tiles row by row (back to front):
--                      * ground/cliff tile sprites -> sprites.tileBatch
--                      * cliffs hide sprites behind them on canvas.object
--                      * sprites (trees, crops, player) -> canvas.object,
--                        each queuing its shadow
--   3. Shadows       spriteShadow:flush - all sprite shadows -> canvas.shadow
--   4. Ground        tileBatch -> canvas.offscreen (one draw call)
--   5. Lighting      lighting:composite - shadows, cliff lighting, lamp, LUT
--   6. Present       view:present - scale canvas.intermediate to the window, draw UI

local appWidth, appHeight
local accumulator = 0 -- For fixed time-step
local alpha = 0 -- For interpolation
local seed -- Pseudorandom seed for map updates
local debugFontSmall, debugFontLarge

function love.load()
    spriteMap = require("spritemap")
    mapArray = require("maps.map01")
    --message = require("message") -- Load message module

    love.window.setMode(1280, 800, {resizable=true, vsync=false})
    love.window.setTitle("Scattered Verses")
    love.graphics.setDefaultFilter("nearest", "nearest")

    appWidth, appHeight = love.graphics.getDimensions()
    require("src/require")
    requireAll()

    -- Fonts are created once; making them every frame leaks memory fast.
    debugFontSmall = love.graphics.newFont(12)
    debugFontLarge = love.graphics.newFont(32)

    seed = 1 -- Starting seed for xorshift16 map updates

    view:resize(appWidth, appHeight)  -- size the game view for the starting zoom
end

function love.resize(w, h)
    appWidth, appHeight = w, h
    view:resize(appWidth, appHeight)
    ui:resize(appWidth, appHeight)
end

function love.keypressed(key)
    if message.isActive then
        if message:keypressed(key) then
            return -- Key handled by message system
        end
    end
    if key == "c" then
        canvas.showSurfaceMap = not canvas.showSurfaceMap
    elseif key == "z" then
        view:step(1, appWidth, appHeight)    -- zoom in one level
    elseif key == "x" then
        view:step(-1, appWidth, appHeight)   -- zoom out one level
    elseif key == "a" or key == "s" or key == "r" then
        ui:keypressed(key)
    else
        player:keypressed(key)
    end
end

function love.keyreleased(key)
    if not message.isActive then
        player:keyreleased(key)
    end
end

function love.update(dt)
    local fixedDt = 1 / 60
    accumulator = accumulator + dt

    while accumulator >= fixedDt do
        if not message.isActive then
            player:update(fixedDt)
        end
        sun:update(fixedDt)      -- day/night cycle (+ M/N to scrub time)
        ui:update(fixedDt) -- Update UI animations
        message:update(fixedDt) -- Update message typing

        for i = 1, 20 do
            -- Map update using xorshift16 (grow watered crop stages 1-7 to next dry stage)
            seed = xorshift16(seed)
            if seed <= 10000 then
                local index = seed
                local y = math.floor((index - 1) / 100) + 1 -- Row 1-100
                local x = ((index - 1) % 100) + 1 -- Column 1-100
                local tileData = mapArray[y] and mapArray[y][x]
                if tileData then
                    local t = tileData[1]
                    if t >= 73 and t <= 85 and t % 2 == 1 then
                        tileData[1] = t + 1
                    end
                end
            end
        end

        -- Update object animations
        for _, obj in ipairs(object.objects) do
            obj.animationTime = obj.animationTime + fixedDt
        end
        accumulator = accumulator - fixedDt
    end
    alpha = accumulator / fixedDt

    if love.keyboard.isDown('escape') then
        love.event.quit()
    end
    -- Zoom glide (Z / X); resizes the game view when needed.
    view:update(dt, appWidth, appHeight)

    player.isNearOutlinedObject = false
end

-- Draws one row's sprites ("specials") back to front.
local function drawSpecial(item)
    local a = item.args
    if item.type == "crop" then
        crop:draw(a[1], a[2], a[3], a[4], a[5], a[6])
    elseif item.type == "tree" then
        tree:draw(a[1], a[2], a[3], a[4], a[5])
    elseif item.type == "object" then
        --object:drawSingle(unpack(a))
    elseif item.type == "tallGrass" then
        -- (tall grass drawing currently disabled)
    elseif item.type == "player" then
        player:draw(a[1], a[2], a[3])
    end
end

-- Sort sprites within a row by where they touch the ground (lower on screen
-- = closer to the camera = drawn later), then left to right.
local function bySortKey(a, b)
    if a.sortY ~= b.sortY then
        return a.sortY < b.sortY
    end
    return a.sortX < b.sortX
end

local special = {}       -- reused every row to avoid garbage
local occluders = {}     -- screen rects of this row's cliffs

function love.draw()
    local ts = sprites.size
    canvas:clear()
    sprites.tileBatch:clear()
    spriteShadow:clear()

    local tilesHorizontal = math.ceil(window.width / ts)
    local tilesVertical = math.ceil(window.height / ts)
    local cameraX = player.x - window.width / 2
    local cameraY = player.y - window.height / 2
    local firstTileX = math.floor(cameraX / ts)
    local firstTileY = math.floor(cameraY / ts)
    local offsetX = cameraX % ts
    local offsetY = cameraY % ts

    -- 1. Sun/lamp state for this frame, and the terrain's shape on screen.
    lighting:begin()
    terrain:drawSurfaceMap(cameraX, cameraY)

    -- 2. Scene, one tile row at a time from the back (top) to the front.
    -- Rows below the screen are included (+ maxHeight) because tall cliffs
    -- there reach up into view.
    local extraRows = math.ceil(terrain.maxHeight / ts) + 1
    for y = 0, tilesVertical + extraRows do
        local yC = firstTileY + y
        if yC < 1 or yC > #mapArray then goto continueY end

        for i = #special, 1, -1 do special[i] = nil end
        local occluderCount = 0

        for x = -5, tilesHorizontal + 5 do
            local xC = firstTileX + x
            local cell = mapArray[yC][xC]
            if not cell then goto continueX end

            -- Screen position of this tile at ground level.
            local screenX = (x - 1) * ts - offsetX
            local screenY = (y - 1) * ts - offsetY
            local tile, z = cell[1], cell[2]

            if z ~= 0 then
                mountain:add(xC, yC, z, screenX, screenY)
                occluderCount = occluderCount + 1
                occluders[occluderCount] = {mountain:footprint(z, screenX, screenY)}
            end

            -- Every tile type sits on grass.
            grass:add(xC, yC, z, screenX, screenY)

            -- Sprites are sorted by the screen y where they touch the ground.
            if tile == 1 then
                grass:addFlourish(xC, yC, z, screenX, screenY)
            elseif tile == 10 then
                special[#special + 1] = { sortY = screenY, sortX = screenX, type = "tallGrass",
                    args = {xC, yC, z, screenX, screenY} }
            elseif tile == 56 then
                dirt:add(xC, yC, z, screenX, screenY)
            elseif tile >= 72 and tile <= 87 then
                dirt:add(xC, yC, z, screenX, screenY)
                if tile % 2 == 1 then
                    -- Wet-soil overlay for watered (odd) stages, drawn under the plant.
                    special[#special + 1] = { sortY = screenY + 23, sortX = screenX, type = "crop",
                        args = {xC, yC, z, screenX, screenY, 70} }
                end
                special[#special + 1] = { sortY = screenY + 24, sortX = screenX, type = "crop",
                    args = {xC, yC, z, screenX, screenY, tile} }
            elseif tile == 512 then
                special[#special + 1] = { sortY = screenY + 26, sortX = screenX, type = "tree",
                    args = {xC, yC, z, screenX, screenY} }
            end
            ::continueX::
        end

        -- Cliffs in this row hide anything already drawn behind them.
        -- (Objects in this same row are drawn after this, so stay in front.)
        if occluderCount > 0 then
            love.graphics.setCanvas(canvas.object)
            love.graphics.setBlendMode("replace")
            love.graphics.setColor(0, 0, 0, 0)
            for i = 1, occluderCount do
                local r = occluders[i]
                love.graphics.rectangle("fill", r[1], r[2], r[3], r[4])
            end
            love.graphics.setBlendMode("alpha")
            love.graphics.setColor(1, 1, 1, 1)
        end

        -- The player belongs to the row his feet are in.
        if math.floor(player.y / ts) + 1 == yC then
            special[#special + 1] = { sortY = player.y - cameraY, sortX = player.x - cameraX,
                type = "player", args = {cameraX, cameraY, alpha} }
        end

        table.sort(special, bySortKey)
        for _, item in ipairs(special) do
            drawSpecial(item)
        end

        ::continueY::
    end

    -- 3. Every queued sprite shadow in one pass.
    spriteShadow:flush(lighting.sun, lighting.lamp, cameraX, cameraY)

    -- 4. Ground tiles.
    love.graphics.setCanvas(canvas.offscreen)
    love.graphics.draw(sprites.tileBatch)
    player:drawOutline(cameraX, cameraY, mapArray)

    -- 5. Lighting, shadows and colour grading.
    lighting:composite(cameraX, cameraY)

    -- Debug (C key): overlay the surface map.
    if canvas.showSurfaceMap then
        love.graphics.setShader(shader.surfaceDebug)
        shader.surfaceDebug:send("heightRange", terrain.heightRange)
        shader.surfaceDebug:send("maxTerrainHeight", terrain.maxHeight)
        love.graphics.draw(canvas.surface)
        love.graphics.setShader()
    end

    -- 6. Scale up to the window (crisp, see view.lua).
    view:present(appWidth, appHeight)

    -- Draw inventory UI if not showing message box
    if not message.isActive then
        ui:drawInventory(appWidth, appHeight)
    end

    -- Draw message box
    message:draw(appWidth, appHeight)

    -- Debug readout
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(debugFontSmall)
    local stats = love.graphics.getStats()
    love.graphics.print("Player Z: " .. player.z, 10, 10)
    love.graphics.print("IsOnGround: " .. tostring(player.isOnGround), 10, 30)
    love.graphics.print("Player Jump: " .. tostring(player.jump), 10, 50)
    love.graphics.print(string.format("Sun Angle: %.1f", sun.angle), 10, 70)
    love.graphics.print("Draw Calls: " .. stats.drawcalls, 10, 90)
    love.graphics.print("Canvas Switches: " .. stats.canvasswitches, 10, 110)
    love.graphics.print(string.format("Zoom: %.2fx  (view %dx%d)", view.displayZoom, window.width, window.height), 10, 130)
    love.graphics.setFont(debugFontLarge)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 150)
end
