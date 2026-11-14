-- tallgrass.lua
--
-- Tall grass (tile type 10): clumps of img/grass3.png standing on the tile.
--
--   * Each tall-grass tile has CLUMPS clumps at fixed, varied spots. They're
--     sprites sorted with the player and trees (main.lua's row items), so
--     grass in front of the player's feet covers his legs and grass behind
--     him stays behind.
--   * WIND: every clump sways a little on its own, and gusts roll across the
--     field in the clouds' wind direction (clouds.windX / windY).
--   * WALKING THROUGH: each clump near the player is a little spring. It's
--     pushed to lean away from his feet and wobbles back after he's gone.
--     Only clumps that are being pushed or are still moving are simulated.
--   * CUTTING: the Hoe (F) cuts tall grass back to plain grass (player.lua
--     calls tallGrass:cut), throwing up a few blade particles.
--
-- A clump is drawn sheared (love.graphics.draw's kx) about its base, so its
-- top leans while its roots stay put.

local tallGrass = {}
package.loaded[...] = tallGrass  -- register now, so modules that require each other share this table

local canvas = require("src.canvas")
local clouds = require("src.clouds")
local lighting = require("src.lighting")
local player = require("src.player")
local sprites = require("src.sprites")
local terrain = require("src.terrain")
local mapArray = require("src.level").cells

local CLUMPS = 3               -- clumps per tile
local CLUMP_H = 27             -- sprite height (img/grass3.png is 32 x 27)
local CLUMP_ORIGIN_X = 16      -- drawn with its bottom-centre on the clump's base point

-- Wind
local SWAY_PX  = 1.2           -- gentle lean back and forth (px at the tip)
local SWAY_SPEED = 2.1         -- radians per second
local GUST_PX  = 3.5           -- extra lean at a gust's peak
local GUST_SPEED = 1.5         -- how fast gusts roll across the field
local GUST_SPACING = 0.012     -- radians per px along the wind (wave length ~520 px)

-- Walking through
local PUSH_RADIUS = 15         -- px from the player's feet (sideways) that a clump is pushed
local PUSH_DEPTH = 9           -- px north/south of his feet
local PUSH_PX = 10             -- lean (px at the tip) right next to him
local PUSH_MAX_ABOVE = 14      -- feet more than this above the ground (a jump) don't push
local STIFFNESS = 170          -- spring pull back toward the target lean
local DAMPING = 9              -- how quickly the wobble dies down

-- Cutting
local PARTICLES = 16
local GRAVITY = 420            -- px/s^2 (pulling particles back to the ground)
local BLADE_COLOURS = { {0.45, 0.62, 0.16}, {0.36, 0.52, 0.12}, {0.58, 0.72, 0.24} }

-- A repeatable pseudo-random number 0..1 for (a, b, c).
local function hash(a, b, c)
    local v = math.sin(a * 12.9898 + b * 78.233 + c * 37.719) * 43758.5453
    return v - math.floor(v)
end

-- Clump i of tile (col, row): offset of its base inside the tile, and
-- whether it's mirrored. Spread back / middle / front so the tile looks full.
local ROW_Y = { 11, 20, 29 }
local COL_X = { 9, 23, 15 }
local function clumpLayout(col, row, i)
    local ox = COL_X[i] + (hash(col, row, i) - 0.5) * 8
    local oy = ROW_Y[i] + (hash(row, col, i + 7) - 0.5) * 5
    local flip = hash(col + 3, row, i) < 0.5 and -1 or 1
    return ox, oy, flip
end

-- Spring state of clumps that are being pushed or still moving, by key.
local springs = {}
local function key(col, row, i) return (row * 4096 + col) * 4 + i end

local particles = {}

-- Lean (px at the tip, + = east) from the wind for a clump at world (x, y).
local function windLean(x, y, t, phase)
    local wx, wy = clouds.windX, clouds.windY
    local len = math.sqrt(wx * wx + wy * wy)
    if len < 1e-6 then return 0 end
    wx, wy = wx / len, wy / len
    local sway = math.sin(t * SWAY_SPEED + phase * 6.283) * SWAY_PX
    local g = math.sin((x * wx + y * wy) * GUST_SPACING - t * GUST_SPEED)
    local gust = g > 0 and g ^ 4 * GUST_PX or 0
    return (sway + gust) * (wx >= 0 and 1 or -1)
end

-- Fixed-timestep update: push clumps around the player's feet, let the rest
-- spring back, and move cut-grass particles.
function tallGrass:update(dt)
    local ts = sprites.size
    local px, py = player.x + 16, player.y          -- his feet
    local feet = -player.z
    local pushed = {}

    local c0, c1 = math.floor((px - PUSH_RADIUS) / ts) + 1, math.floor((px + PUSH_RADIUS) / ts) + 1
    local r0, r1 = math.floor((py - PUSH_DEPTH) / ts) + 1, math.floor((py + PUSH_DEPTH) / ts) + 1
    for row = r0, r1 do
        for col = c0, c1 do
            local cell = mapArray[row] and mapArray[row][col]
            if cell and cell[1] == 10 then
                for i = 1, CLUMPS do
                    local ox, oy = clumpLayout(col, row, i)
                    local cx, cy = (col - 1) * ts + ox, (row - 1) * ts + oy
                    local dx, dy = cx - px, cy - py
                    local ground = terrain:surfaceHeight(cx, cy)
                    if math.abs(dx) < PUSH_RADIUS and math.abs(dy) < PUSH_DEPTH and feet - ground < PUSH_MAX_ABOVE then
                        -- Lean away from him; straight under him, away from the way he faces.
                        local side = dx > 0.5 and 1 or (dx < -0.5 and -1 or (player.direction == "Left" and -1 or 1))
                        local k = key(col, row, i)
                        springs[k] = springs[k] or { bend = 0, vel = 0 }
                        pushed[k] = side * (1 - math.abs(dx) / PUSH_RADIUS) * PUSH_PX
                    end
                end
            end
        end
    end

    for k, s in pairs(springs) do
        local target = pushed[k] or 0
        s.vel = s.vel + ((target - s.bend) * STIFFNESS - s.vel * DAMPING) * dt
        s.bend = s.bend + s.vel * dt
        if not pushed[k] and math.abs(s.bend) < 0.05 and math.abs(s.vel) < 0.05 then
            springs[k] = nil        -- settled
        end
    end

    for i = #particles, 1, -1 do
        local p = particles[i]
        p.x, p.y, p.z = p.x + p.vx * dt, p.y + p.vy * dt, p.z + p.vz * dt
        p.vz = p.vz - GRAVITY * dt
        p.life = p.life - dt
        if p.life <= 0 or p.z < p.ground then table.remove(particles, i) end
    end
end

-- Called while building the scene (main.lua, via tiles.lua): adds the
-- tile's clumps to the row's draw list.
function tallGrass:addSprites(list, xC, yC, z, screenX, screenY)
    local ts = sprites.size
    local tileX, tileY = (xC - 1) * ts, (yC - 1) * ts
    local t = love.timer.getTime()
    -- One light level for the whole tile (sun, shadows, clouds): the clumps
    -- are small and close together, and this is far cheaper than per clump.
    local tint = lighting:objectTint(tileX + 16, tileY + 16, -z + 8, nil)
    for i = 1, CLUMPS do
        local ox, oy, flip = clumpLayout(xC, yC, i)
        local wx, wy = tileX + ox, tileY + oy
        local h = terrain:surfaceHeight(wx, wy)
        local s = springs[key(xC, yC, i)]
        local lean = windLean(wx, wy, t, hash(xC, yC, i + 13)) + (s and s.bend or 0)
        list[#list + 1] = {
            owner = self, tint = tint,
            sortY = screenY + oy, sortX = screenX + ox,
            drawX = screenX + ox, drawY = screenY + oy - h,
            flip = flip, shear = -lean / CLUMP_H,
            tintX = wx, tintY = wy, tintZ = h + 8,
        }
    end
end

-- Draws one clump onto canvas.object with brightness `tint`.
function tallGrass:drawItem(item, tint)
    love.graphics.setCanvas(canvas.object)
    love.graphics.setColor(tint, tint, tint, 1)
    love.graphics.draw(sprites.grass, sprites.grassQuad, item.drawX, item.drawY, 0,
        item.flip, 1, CLUMP_ORIGIN_X, CLUMP_H, item.shear * item.flip, 0)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Cuts tile (col, row) back to plain grass, throwing up blade particles.
function tallGrass:cut(col, row)
    local cell = mapArray[row] and mapArray[row][col]
    if not cell or cell[1] ~= 10 then return false end
    cell[1] = 1
    local ts = sprites.size
    for i = 1, CLUMPS do springs[key(col, row, i)] = nil end
    for n = 1, PARTICLES do
        local x = (col - 1) * ts + 4 + love.math.random() * 24
        local y = (row - 1) * ts + 6 + love.math.random() * 24
        local ground = terrain:surfaceHeight(x, y)
        particles[#particles + 1] = {
            x = x, y = y, z = ground + 4 + love.math.random() * 14, ground = ground,
            vx = (love.math.random() - 0.5) * 120, vy = (love.math.random() - 0.5) * 40,
            vz = 70 + love.math.random() * 90,
            life = 0.5 + love.math.random() * 0.4,
            colour = BLADE_COLOURS[love.math.random(#BLADE_COLOURS)],
            long = love.math.random() < 0.5,
        }
    end
    return true
end

-- Draws the flying blade bits onto canvas.object (after the scene's
-- sprites, so they're on top), lit like the scene.
function tallGrass:drawParticles(cameraX, cameraY)
    if #particles == 0 then return end
    love.graphics.setCanvas(canvas.object)
    local light = lighting.sun and lighting.sun.litLevel or 1
    for _, p in ipairs(particles) do
        local c = p.colour
        love.graphics.setColor(c[1] * light, c[2] * light, c[3] * light, math.min(1, p.life * 4))
        local sx, sy = math.floor(p.x - cameraX + 0.5), math.floor(p.y - p.z - cameraY + 0.5)
        if p.long then
            love.graphics.rectangle("fill", sx, sy, 1, 3)
        else
            love.graphics.rectangle("fill", sx, sy, 2, 1)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return tallGrass
