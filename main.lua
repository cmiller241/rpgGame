-- main.lua
--
-- FRAME OVERVIEW (love.draw)
--   1. Surface map   terrain:drawSurfaceMap - per-pixel terrain shape for lighting
--   2. Collect       walk the visible tiles row by row (back to front):
--                      * ground/cliff tile sprites -> sprites.tileBatch
--                      * sprites (trees, crops, pages, player) become draw
--                        items, each queuing its shadow caster
--   3. Shadows       spriteShadow:flush - all sprite shadows -> canvas.shadow
--   4. Draw sprites  row by row: cliffs hide what's behind them, then the
--                    row's sprites are drawn, tinted if they stand in a cliff's
--                    or another sprite's shadow (needs every caster, hence
--                    collecting first)
--   5. Ground        tileBatch -> canvas.offscreen (one draw call)
--   6. Lighting      lighting:composite - shadows, cliff lighting, lamp, LUT
--   7. Present       view:present - scale to the window, then the UI
--
-- Run with `--shots` or `--bench` for developer tools (see src/devtools.lua).
--
-- MODULES
-- Every file in src/ is a module: it builds a local table, registers it in
-- package.loaded straight away, requires what it needs, and returns the
-- table. Registering first means two modules that need each other (e.g.
-- player and message) get the same table instead of looping forever, as long
-- as neither uses the other while it's still loading.

-- Pixel art: images must be loaded with nearest-neighbour filtering, so set
-- the default before any module loads an image.
love.graphics.setDefaultFilter("nearest", "nearest")

local mapArray     = require("maps.map01")
local xorshift16   = require("src.xorshift")
local window       = require("src.window")
local canvas       = require("src.canvas")
local view         = require("src.view")
local camera       = require("src.camera")
local shader       = require("src.shader")
local sun          = require("src.sun")
local sprites      = require("src.sprites")
local terrain      = require("src.terrain")
local spriteShadow = require("src.spriteShadow")
local lighting     = require("src.lighting")
local tiles        = require("src.tiles")
local mountain     = require("src.mountain")
local grass        = require("src.grass")
local dirt         = require("src.dirt")
local player       = require("src.player")
local object       = require("src.objects")
local ui           = require("src.ui")
local message      = require("src.message")
local devtools     = require("src.devtools")

local appWidth, appHeight
local accumulator = 0 -- For fixed time-step
local alpha = 0       -- How far into the next update tick we are (0..1), for smooth drawing
local seed            -- Pseudorandom seed for map updates
local debugFontSmall, debugFontLarge

function love.load(args)
    love.window.setMode(1280, 800, {resizable=true, vsync=false})
    love.window.setTitle("Scattered Verses")

    appWidth, appHeight = love.graphics.getDimensions()
    canvas:initialize(window.width, window.height)
    terrain:build(mapArray)
    grass:buildFlourishes()

    -- Fonts are created once; making them every frame leaks memory fast.
    debugFontSmall = love.graphics.newFont(12)
    debugFontLarge = love.graphics.newFont(32)

    seed = 1 -- Starting seed for xorshift16 map updates

    view:resize(appWidth, appHeight)  -- size the game view for the starting zoom
    camera:snap()

    devtools.start(args)              -- no-op unless --shots / --bench was given
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

-- Watered crops grow one stage at random moments: each tick, 20 random
-- cells are checked (xorshift16 visits all 65535 values before repeating,
-- so every cell gets its turn).
local function growCrops()
    for i = 1, 20 do
        seed = xorshift16(seed)
        if seed <= 10000 then
            local y = math.floor((seed - 1) / 100) + 1 -- Row 1-100
            local x = ((seed - 1) % 100) + 1           -- Column 1-100
            local cell = mapArray[y] and mapArray[y][x]
            -- Watered (odd) and not fully grown: becomes the next dry stage.
            if cell and tiles.isWetCrop(cell[1]) and cell[1] < 87 then
                cell[1] = cell[1] + 1
            end
        end
    end
end

function love.update(dt)
    local fixedDt = 1 / 60
    accumulator = accumulator + dt

    while accumulator >= fixedDt do
        player:rememberPosition()      -- for smooth drawing between ticks
        if not message.isActive then
            player:update(fixedDt)
        end
        sun:update(fixedDt)      -- day/night cycle (+ M/N to scrub time)
        ui:update(fixedDt) -- Update UI animations
        message:update(fixedDt) -- Update message typing
        growCrops()

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

    player:updateDrawPosition(alpha)
    view:update(dt, appWidth, appHeight)   -- zoom glide (Z / X); resizes the game view when needed
    camera:update(dt)                      -- follow the player, clamped to the map
end

-- Sort sprites within a row by where they touch the ground (lower on screen
-- = closer to the camera = drawn later), then left to right.
local function bySortKey(a, b)
    if a.sortY ~= b.sortY then
        return a.sortY < b.sortY
    end
    return a.sortX < b.sortX
end

-- Extra tiles processed beyond the screen edges, so things just off screen
-- still cast shadows into view: a tree (~250 px tall) at the lowest sun
-- (45 degrees) throws a shadow ~250 px, about 8 tiles.
local MARGIN_TILES = 9

local rows = {}  -- per visible map row: { items = {...}, occluders = {...} }, reused each frame

function love.draw()
    local ts = sprites.size
    canvas:clear()
    sprites.tileBatch:clear()
    spriteShadow:clear()

    local cameraX, cameraY = camera:get()
    local tilesHorizontal = math.ceil(window.width / ts)
    local tilesVertical = math.ceil(window.height / ts)
    local firstTileX = math.floor(cameraX / ts)
    local firstTileY = math.floor(cameraY / ts)
    local offsetX = cameraX % ts
    local offsetY = cameraY % ts

    -- 1. Sun/lamp state for this frame, and the terrain's shape on screen.
    lighting:begin()
    terrain:drawSurfaceMap(cameraX, cameraY)

    -- Which row each Bible page and the player belong to.
    local pagesByRow = {}
    for _, obj in ipairs(object.objects) do
        local r = object:rowOf(obj)
        pagesByRow[r] = pagesByRow[r] or {}
        table.insert(pagesByRow[r], obj)
    end
    local playerRow = math.floor(player.drawY / ts) + 1

    -- 2. Collect, one tile row at a time from the back (top) to the front.
    -- Rows below the screen are included because tall cliffs there reach up
    -- into view and sprites there cast shadows up into view.
    local extraRows = math.max(math.ceil(terrain.maxHeight / ts) + 1, MARGIN_TILES)
    local rowCount = 0
    for y = 0, tilesVertical + extraRows do
        local yC = firstTileY + y
        if yC >= 1 and yC <= #mapArray then
            rowCount = rowCount + 1
            local row = rows[rowCount] or { items = {}, occluders = {} }
            rows[rowCount] = row
            local items, occluders = row.items, row.occluders
            for i = #items, 1, -1 do items[i] = nil end
            for i = #occluders, 1, -1 do occluders[i] = nil end

            for x = -MARGIN_TILES, tilesHorizontal + MARGIN_TILES do
                local xC = firstTileX + x
                local cell = mapArray[yC][xC]
                if cell then
                    -- Screen position of this tile at ground level.
                    local screenX = (x - 1) * ts - offsetX
                    local screenY = (y - 1) * ts - offsetY
                    local tile, z = cell[1], cell[2]
                    local def = tiles.get(tile)

                    if z ~= 0 then
                        mountain:add(xC, yC, z, screenX, screenY)
                        occluders[#occluders + 1] = {mountain:footprint(z, screenX, screenY)}
                    end

                    grass:add(xC, yC, z, screenX, screenY)  -- every tile sits on grass
                    if def.ground == "dirt" then dirt:add(xC, yC, z, screenX, screenY) end
                    if def.flourish then grass:addFlourish(xC, yC, z, screenX, screenY) end
                    if def.addSprites then def.addSprites(items, xC, yC, z, screenX, screenY, tile) end
                end
            end

            for _, obj in ipairs(pagesByRow[yC] or {}) do
                object:addSprites(items, obj, cameraX, cameraY)
            end
            if yC == playerRow then
                player:addSprites(items, cameraX, cameraY)
            end
        end
    end

    -- 3. Every queued sprite shadow (one draw call per sprite sheet).
    spriteShadow:flush(lighting.sun, lighting.lamp, cameraX, cameraY)

    -- 4. Sprites, back to front.
    for r = 1, rowCount do
        local row = rows[r]

        -- Cliffs in this row hide anything already drawn behind them.
        -- (This row's own sprites are drawn after, so they stay in front.)
        if #row.occluders > 0 then
            love.graphics.setCanvas(canvas.object)
            love.graphics.setBlendMode("replace")
            love.graphics.setColor(0, 0, 0, 0)
            for _, o in ipairs(row.occluders) do
                love.graphics.rectangle("fill", o[1], o[2], o[3], o[4])
            end
            love.graphics.setBlendMode("alpha")
            love.graphics.setColor(1, 1, 1, 1)
        end

        table.sort(row.items, bySortKey)
        for _, item in ipairs(row.items) do
            local tint = lighting:objectTint(item.tintX, item.tintY, item.tintZ, item.caster)
            item.owner:drawItem(item, tint)
        end
    end

    -- 5. Ground tiles.
    love.graphics.setCanvas(canvas.offscreen)
    love.graphics.draw(sprites.tileBatch)
    player:drawOutline(cameraX, cameraY, mapArray)

    -- 6. Lighting, shadows and colour grading.
    lighting:composite(cameraX, cameraY)

    -- Debug (C key): overlay the surface map.
    if canvas.showSurfaceMap then
        love.graphics.setShader(shader.surfaceDebug)
        shader.surfaceDebug:send("heightRange", terrain.heightRange)
        shader.surfaceDebug:send("maxTerrainHeight", terrain.maxHeight)
        love.graphics.draw(canvas.surface)
        love.graphics.setShader()
    end

    -- 7. Scale up to the window (crisp, see view.lua).
    view:present(appWidth, appHeight)

    -- Draw inventory UI if not showing message box
    if not message.isActive then
        ui:drawInventory(appWidth, appHeight)
    end

    -- Draw message box
    message:draw(appWidth, appHeight)

    if devtools.hideOverlay then return end

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
