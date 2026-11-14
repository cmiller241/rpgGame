-- splash.lua
--
-- Water reacting to the player:
--   * RIPPLES: rings spreading on the surface around his feet while he wades
--     (one every RIPPLE_STEP seconds as he moves, a slow gentle one while he
--     stands still), plus a big ring when he splashes in.
--   * SPLASHES: droplets jump up and fall back, each making a tiny ring
--     where it lands (if that's water): a small splash when he wades in, a
--     big one (more drops, higher, two rings) when he jumps or falls in, and
--     one when he jumps out.
--
-- Both are sprites sorted with everything else per row (main.lua). Rings are
-- drawn by shaders/rippleShader.glsl as two halves (behind him / in front of
-- his legs) in solid pixels that fade with a dither pattern, so they're lit
-- like sprites (shadow, night, lamp) and not tinted away by the water.

local splash = {}
package.loaded[...] = splash  -- register now, so modules that require each other share this table

local canvas = require("src.canvas")
local player = require("src.player")
local shader = require("src.shader")
local sprites = require("src.sprites")
local water = require("src.water")

local RIPPLE_STEP = 0.32          -- s between rings while wading
local RIPPLE_IDLE = 1.4           -- s between rings while standing in water
local RING_SQUASH = 0.5           -- height / width (seen at an angle)
local RING_COLOUR = { 0.78, 0.92, 1.0 }
local DROPS = 14                  -- droplets in a splash
local DROP_COLOUR = { 0.82, 0.94, 1.0 }
local GRAVITY = 380               -- px/s^2
local SPLASH_IN   = 1.7           -- splash strength: jumping / falling into water
local SPLASH_OUT  = 1.3           -- jumping out of it
local SPLASH_WADE = 0.8           -- walking in

local dot = love.graphics.newImage(love.image.newImageData(1, 1, "rgba8", string.char(255, 255, 255, 255)))

local rings, drops = {}, {}
local wasInWater, wasOnGround = false, true
local lastSurface                -- water surface at his feet last tick (for jumping out)
local rippleTimer = 0
local lastX, lastY

-- Water surface height (px) at world point (x, y), or nil if it's dry.
local function surfaceAt(x, y)
    local ts = sprites.size
    return water:surfaceAt(math.floor(x / ts) + 1, math.floor(y / ts) + 1)
end

local function ring(x, y, z, size, life)
    rings[#rings + 1] = { x = x, y = y, z = z, size = size, age = 0, life = life }
end

-- A ripple ring on the water at (x, y), surface height z (e.g. a raindrop).
function splash:ring(x, y, z, size, life)
    if #rings < 120 then ring(x, y, z, size, life) end
end

-- A splash at (x, y) on the water surface z: droplets and a big ring.
function splash:splash(x, y, z, strength)
    strength = strength or 1
    ring(x, y, z, 22 * strength, 0.9)
    if strength > 1.2 then ring(x, y, z, 12 * strength, 0.6) end     -- a second, inner ring
    for i = 1, math.floor(DROPS * strength * strength) do
        local a = love.math.random() * 2 * math.pi
        local speed = (20 + love.math.random() * 30) * math.sqrt(strength)
        drops[#drops + 1] = {
            x = x + math.cos(a) * 4, y = y + math.sin(a) * 2, z = z + 2,
            vx = math.cos(a) * speed, vy = math.sin(a) * speed * 0.5,
            vz = (70 + love.math.random() * 70) * strength, life = 1.2,
        }
    end
end

-- Fixed-timestep update.
function splash:update(dt)
    local fx, fy = player.x + 16, player.y - 2
    local feet = -player.z
    local depth = water:depthAtFeet(fx, player.y - 4, feet)
    local inWater = depth > 0
    local surface = surfaceAt(fx, fy)
    local moved = lastX ~= nil and (player.x ~= lastX or player.y ~= lastY)
    lastX, lastY = player.x, player.y

    if inWater and surface then
        local landed = player.isOnGround and not wasOnGround
        if not wasInWater or landed then
            -- Jumping or falling in makes a big splash; wading in, a small one.
            local fromAir = landed or not player.isOnGround
            self:splash(fx, fy, surface, fromAir and SPLASH_IN or SPLASH_WADE)
            rippleTimer = 0
        else
            rippleTimer = rippleTimer + dt
            local step = moved and RIPPLE_STEP or RIPPLE_IDLE
            if rippleTimer >= step then
                rippleTimer = 0
                ring(fx, fy, surface, moved and 16 or 12, moved and 0.8 or 1.2)
            end
        end
    end
    -- Jumping out: his feet just left the water and he's in the air.
    if wasInWater and not inWater and not player.isOnGround and lastSurface then
        self:splash(fx, fy, lastSurface, SPLASH_OUT)
    end
    wasInWater, wasOnGround = inWater, player.isOnGround
    lastSurface = surface

    for i = #rings, 1, -1 do
        local r = rings[i]
        r.age = r.age + dt
        if r.age >= r.life then table.remove(rings, i) end
    end
    for i = #drops, 1, -1 do
        local d = drops[i]
        d.x, d.y, d.z = d.x + d.vx * dt, d.y + d.vy * dt, d.z + d.vz * dt
        d.vz = d.vz - GRAVITY * dt
        d.life = d.life - dt
        local s = surfaceAt(d.x, d.y)
        local floor = s or -1000
        if d.vz < 0 and d.z <= floor then
            ring(d.x, d.y, s, 6, 0.5)                 -- plip
            table.remove(drops, i)
        elseif d.life <= 0 then
            table.remove(drops, i)
        end
    end
end

-- Adds the rings and droplets in tile row `row` to that row's draw list.
function splash:addSprites(list, row, cameraX, cameraY)
    local ts = sprites.size
    for _, r in ipairs(rings) do
        if math.floor(r.y / ts) + 1 == row then
            for _, part in ipairs({ -1, 1 }) do
                list[#list + 1] = {
                    owner = self, ring = r, part = part,
                    sortY = r.y - cameraY + part * 0.5, sortX = r.x - cameraX,
                    tintX = r.x, tintY = r.y, tintZ = r.z,
                    screenX = r.x - cameraX, screenY = r.y - r.z - cameraY,
                }
            end
        end
    end
    for _, d in ipairs(drops) do
        if math.floor(d.y / ts) + 1 == row then
            list[#list + 1] = {
                owner = self, drop = d,
                sortY = d.y - cameraY + 0.6, sortX = d.x - cameraX,
                tintX = d.x, tintY = d.y, tintZ = d.z,
                screenX = d.x - cameraX, screenY = d.y - d.z - cameraY,
            }
        end
    end
end

-- Draws a ring half or a droplet onto canvas.object with brightness `tint`.
function splash:drawItem(item, tint)
    love.graphics.setCanvas(canvas.object)
    if item.drop then
        love.graphics.setColor(DROP_COLOUR[1] * tint, DROP_COLOUR[2] * tint, DROP_COLOUR[3] * tint, 1)
        love.graphics.rectangle("fill", math.floor(item.screenX + 0.5), math.floor(item.screenY + 0.5), 2, 2)
        love.graphics.setColor(1, 1, 1, 1)
        return
    end
    local r = item.ring
    local t = r.age / r.life
    local w = r.size * (0.35 + 0.65 * math.sqrt(t))          -- spreads fast, then slows
    local h = math.max(2, w * RING_SQUASH)
    local s = shader.ripple
    love.graphics.setShader(s)
    shader.sendIfPresent(s, "sizePx", { w, h })
    shader.sendIfPresent(s, "thickness", 1.2)
    shader.sendIfPresent(s, "fade", math.sqrt(1 - t))          -- stays solid, then thins out
    shader.sendIfPresent(s, "part", item.part)
    love.graphics.setColor(RING_COLOUR[1] * tint, RING_COLOUR[2] * tint, RING_COLOUR[3] * tint, 1)
    love.graphics.draw(dot, math.floor(item.screenX - w / 2 + 0.5), math.floor(item.screenY - h / 2 + 0.5), 0, w, h)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setShader()
end

return splash
