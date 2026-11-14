-- fireflies.lua
--
-- After dusk, fireflies drift around: each wanders slowly a little above
-- the ground, bobbing, and blinks: a slow glow that rises, holds, fades,
-- then a few seconds dark. They come out as night falls (sun.night) and
-- leave again at dawn, kept to the area around the screen.
--
-- Like the motes around the Bible pages they glow, so they're drawn after
-- the lighting pass, added onto the lit frame with
-- shaders/sparkleShader.glsl (main.lua calls fireflies:draw).

local fireflies = {}
package.loaded[...] = fireflies  -- register now, so modules that require each other share this table

local camera = require("src.camera")
local canvas = require("src.canvas")
local shader = require("src.shader")
local sun = require("src.sun")
local weather = require("src.weather")
local terrain = require("src.terrain")
local window = require("src.window")

local MAX = 16                    -- at full night, around the screen
local NIGHT_START = 0.45          -- sun.night where they start to appear
local MARGIN = 40                 -- px around the screen they live in
local SPEED_MIN, SPEED_MAX = 5, 11      -- px/s
local HEIGHT_MIN, HEIGHT_MAX = 6, 30    -- px above the ground
local BLINK_ON = 1.4              -- s from start of a glow to dark again
local DARK_MIN, DARK_MAX = 0.8, 2.6     -- s dark between glows
local SIZE = 9                    -- glow sprite size (px)
local COLOUR = { 0.78, 1.0, 0.38 }      -- yellow-green

local dot = love.graphics.newImage(love.image.newImageData(1, 1, "rgba8", string.char(255, 255, 255, 255)))
local batch = love.graphics.newSpriteBatch(dot, 64, "stream")

local flies = {}

local function view()
    local cx, cy = camera:get()
    return cx - MARGIN, cy - MARGIN, cx + window.width + MARGIN, cy + window.height + MARGIN
end

local function spawn()
    local x0, y0, x1, y1 = view()
    flies[#flies + 1] = {
        x = x0 + love.math.random() * (x1 - x0), y = y0 + love.math.random() * (y1 - y0),
        height = HEIGHT_MIN + love.math.random() * (HEIGHT_MAX - HEIGHT_MIN),
        heading = love.math.random() * 2 * math.pi,
        speed = SPEED_MIN + love.math.random() * (SPEED_MAX - SPEED_MIN),
        clock = -love.math.random() * DARK_MAX,          -- < 0: dark, counting up to the next glow
        phase = love.math.random() * 10,
    }
end

-- Fixed-timestep update.
function fireflies:update(dt)
    local night = sun:getState().night or 0
    local want = math.floor(MAX * math.max(0, math.min(1, (night - NIGHT_START) / (1 - NIGHT_START)))
                            * (1 - weather.amount) + 0.5)          -- they hide from the rain
    while #flies < want do spawn() end
    while #flies > want do table.remove(flies) end

    local x0, y0, x1, y1 = view()
    for i, f in ipairs(flies) do
        f.heading = f.heading + (love.math.random() - 0.5) * 3 * dt
        f.x = f.x + math.cos(f.heading) * f.speed * dt
        f.y = f.y + math.sin(f.heading) * f.speed * 0.7 * dt
        f.clock = f.clock + dt
        if f.clock > BLINK_ON then f.clock = -(DARK_MIN + love.math.random() * (DARK_MAX - DARK_MIN)) end
        -- Wandered well off screen (or the screen moved away): start again somewhere in view.
        if f.x < x0 - MARGIN or f.x > x1 + MARGIN or f.y < y0 - MARGIN or f.y > y1 + MARGIN then
            table.remove(flies, i)
            spawn()
            break
        end
    end
end

-- Glow of a blink at time `clock` (0..BLINK_ON): rise, hold, fade.
local function glow(clock)
    if clock < 0 then return 0 end
    local t = clock / BLINK_ON
    if t < 0.3 then return t / 0.3 end
    if t < 0.5 then return 1 end
    return 1 - (t - 0.5) / 0.5
end

-- Draws the glowing fireflies onto canvas.intermediate (call right after
-- lighting:composite).
function fireflies:draw(cameraX, cameraY)
    if #flies == 0 then return end
    batch:clear()
    local t = love.timer.getTime()
    for _, f in ipairs(flies) do
        local g = glow(f.clock)
        if g > 0.01 then
            local h = terrain:surfaceHeight(f.x, f.y) + f.height + math.sin(t * 1.7 + f.phase) * 3
            local sx = math.floor(f.x - cameraX + 0.5)
            local sy = math.floor(f.y - h - cameraY + 0.5)
            batch:setColor(COLOUR[1], COLOUR[2], COLOUR[3], g)
            batch:add(sx - math.floor(SIZE / 2), sy - math.floor(SIZE / 2), 0, SIZE, SIZE)
        end
    end
    if batch:getCount() == 0 then return end
    local s = shader.sparkle
    love.graphics.setCanvas(canvas.intermediate)
    love.graphics.setShader(s)
    shader.sendIfPresent(s, "objectCanvas", canvas.object)
    shader.sendIfPresent(s, "screenSize", { window.width, window.height })
    shader.sendIfPresent(s, "behind", false)
    love.graphics.setBlendMode("add")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(batch)
    love.graphics.setBlendMode("alpha")
    love.graphics.setShader()
end

return fireflies
