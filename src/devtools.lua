-- devtools.lua
--
-- Developer tools, started from the command line:
--
--   love . --shots   Renders each scene in SCENES (fixed sun angle, player
--                    position and zoom), saves a PNG of each plus a contact
--                    sheet of them all (shots_sheet.png), then quits. Handy
--                    for checking lighting/shadow changes without walking
--                    to the right spot at the right time of day.
--
--   love . --bench   Renders each scene for a few seconds and prints the
--                    average frame time (also saved to bench.txt).
--
-- Files go to LÖVE's save directory (printed when done; on Windows it's
-- %APPDATA%/LOVE/<game folder name>/). Game updates are frozen while these
-- run, so results are repeatable.

local devtools = {}
package.loaded[...] = devtools  -- register now, so modules that require each other share this table

local camera = require("src.camera")
local canvas = require("src.canvas")
local player = require("src.player")
local sun = require("src.sun")
local terrain = require("src.terrain")
local view = require("src.view")

devtools.hideOverlay = false   -- hides the debug text so screenshots are clean

-- Edit freely. x/y are world pixels of the player's feet; z is his height
-- (negative = up, e.g. -32 for one tile; positive = down in a pit); angle is
-- sun.angle (0 = sunrise, 90 = noon, 180 = sunset, 250 = night); zoom is a
-- whole-number zoom level. Optional `dig` reshapes tiles for that scene
-- only: { {col, row, height}, ... } with height in px (negative = pit).

-- Two pits in the open field east of the cliffs: one tile deep (cols 40-42)
-- and two deep (cols 45-46), each two rows long.
local PITS = {}
for c = 40, 42 do for r = 12, 13 do PITS[#PITS + 1] = { c, r, -32 } end end
for c = 45, 46 do for r = 12, 13 do PITS[#PITS + 1] = { c, r, -64 } end end

local SCENES = {
    { name = "cliffs_morning",   angle = 40,  x = 560, y = 650, zoom = 2 },
    { name = "cliffs_noon",      angle = 90,  x = 560, y = 650, zoom = 2 },
    { name = "cliffs_afternoon", angle = 140, x = 560, y = 650, zoom = 2 },
    { name = "cliffs_dusk",      angle = 172, x = 560, y = 650, zoom = 2 },
    { name = "trees_morning",    angle = 40,  x = 900, y = 260, zoom = 2 },
    { name = "trees_afternoon",  angle = 140, x = 900, y = 260, zoom = 2 },
    -- Same spot beside a lone tree: in its canopy's shadow in the afternoon,
    -- in sunlight in the morning (the player should be darker in the first).
    { name = "in_tree_shade",    angle = 140, x = 1818, y = 660, zoom = 3 },
    { name = "out_of_tree_shade", angle = 40, x = 1818, y = 660, zoom = 3 },
    { name = "pages_and_pines",  angle = 120, x = 900, y = 520, zoom = 2 },
    { name = "plateau_night",    angle = 250, x = 420, y = 570, z = -32, zoom = 3 },
    { name = "zoomed_in_4x",     angle = 120, x = 560, y = 650, zoom = 4 },
    { name = "surface_map",      angle = 60,  x = 560, y = 650, zoom = 2, surfaceMap = true },
    { name = "pits_afternoon",   angle = 140, x = 1376, y = 360, zoom = 3, dig = PITS },
    { name = "pits_morning",     angle = 40,  x = 1376, y = 360, zoom = 3, dig = PITS },
    { name = "standing_in_pit",  angle = 110, x = 1280, y = 408, z = 32, zoom = 4, dig = PITS },
    -- In the 2-deep pit: its floor is completely hidden by the rim normally,
    -- so pit focus should reveal it.
    { name = "in_deep_pit",      angle = 110, x = 1440, y = 408, z = 64, zoom = 4, dig = PITS },
    { name = "pits_surface_map", angle = 110, x = 1376, y = 360, zoom = 3, dig = PITS, surfaceMap = true },
    -- Player hidden behind things: the tree in front should fade, and the
    -- cliff in front should show his ghost.
    { name = "behind_tree",      angle = 110, x = 128,  y = 110, zoom = 3 },
    { name = "behind_cliff",     angle = 110, x = 740,  y = 250, zoom = 3 },
}

local BENCH_SECONDS = 3

-- Tiles reshaped by the current scene's `dig`, with their original heights.
local undoDig = {}

-- Puts the game into a scene's state.
local function applyScene(s)
    for i = #undoDig, 1, -1 do
        local u = undoDig[i]
        terrain:setTileHeight(u[1], u[2], u[3])
        undoDig[i] = nil
    end
    for _, d in ipairs(s.dig or {}) do
        undoDig[#undoDig + 1] = { d[1], d[2], terrain:heightAtTile(d[1], d[2]) }
        terrain:setTileHeight(d[1], d[2], d[3])
    end

    sun.angle = s.angle
    player:teleport(s.x, s.y, s.z or 0)
    view.zoom, view.displayZoom = s.zoom, s.zoom
    view:apply(love.graphics.getDimensions())
    camera:snap()
    canvas.showSurfaceMap = s.surfaceMap or false
end

-- Builds one image with every screenshot as a labelled thumbnail.
local function saveContactSheet(shots)
    local cols, thumbW = 3, 400
    local w, h = shots[1].data:getDimensions()
    local thumbH = math.floor(h * thumbW / w)
    local rowsN = math.ceil(#shots / cols)
    local sheet = love.graphics.newCanvas(cols * thumbW, rowsN * (thumbH + 18))
    love.graphics.setCanvas(sheet)
    love.graphics.clear(0.1, 0.1, 0.1, 1)
    for i, shot in ipairs(shots) do
        local c, r = (i - 1) % cols, math.floor((i - 1) / cols)
        local img = love.graphics.newImage(shot.data)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(img, c * thumbW, r * (thumbH + 18) + 18, 0, thumbW / w, thumbH / h)
        love.graphics.print(shot.name, c * thumbW + 4, r * (thumbH + 18) + 2)
    end
    love.graphics.setCanvas()
    sheet:newImageData():encode("png", "shots_sheet.png")
end

local function startShots(gameDraw)
    devtools.hideOverlay = true
    -- Only a few frames per shot: make fades instant.
    require("src.tree").FADE_SPEED = math.huge
    require("src.lighting").focusFadeTime = 0
    local index, frame, shots = 1, 0, {}

    love.update = function() end   -- freeze the game
    love.draw = function()
        local s = SCENES[index]
        if frame == 0 then applyScene(s) end
        gameDraw()
        frame = frame + 1
        if frame == 3 then   -- give canvases a frame to settle after resizing
            love.graphics.captureScreenshot(function(data)
                data:encode("png", "shot_" .. s.name .. ".png")
                shots[#shots + 1] = { name = s.name, data = data }
                if #shots == #SCENES then
                    saveContactSheet(shots)
                    print("Saved " .. #shots .. " screenshots + shots_sheet.png to " ..
                          love.filesystem.getSaveDirectory())
                    love.event.quit()
                end
            end)
        elseif frame > 3 and index < #SCENES then
            index, frame = index + 1, 0
        end
    end
end

local function startBench(gameDraw)
    local index, elapsed, frames, results = 1, 0, 0, {}
    applyScene(SCENES[1])

    love.update = function(dt)
        elapsed = elapsed + dt
        if elapsed > 0.5 then frames = frames + 1 end       -- skip warm-up
        if elapsed > BENCH_SECONDS + 0.5 then
            local line = string.format("%-18s %6.2f ms/frame", SCENES[index].name, 1000 * BENCH_SECONDS / frames)
            print(line)
            results[#results + 1] = line
            index, elapsed, frames = index + 1, 0, 0
            if index > #SCENES then
                love.filesystem.write("bench.txt", table.concat(results, "\n") .. "\n")
                print("Saved bench.txt to " .. love.filesystem.getSaveDirectory())
                love.event.quit()
                return
            end
            applyScene(SCENES[index])
        end
    end
    love.draw = gameDraw
end

-- Called from love.load with the command-line arguments.
function devtools.start(args)
    for _, a in ipairs(args or {}) do
        if a == "--shots" then return startShots(love.draw) end
        if a == "--bench" then return startBench(love.draw) end
    end
end

return devtools
