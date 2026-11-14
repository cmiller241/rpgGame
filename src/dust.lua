-- dust.lua
--
-- Little puffs of dust kicked up from the player's feet as he walks (and a
-- slightly bigger one when he lands from a jump).
--
-- While he walks on the ground (not in water), every STEP_TIME seconds a
-- couple of puffs appear at one foot, alternating left and right. It drifts back
-- from the way he's going, rises a little, spreads out and fades away.
--
-- Puffs are sprites on the sprite canvas, sorted with everything else per
-- row (main.lua), so his feet and anything in front of them cover them.
-- They're semi-transparent, which means the lighting pass lights them as
-- the ground beneath (in shade, at night, in his lamp's glow). Each puff is
-- drawn by shaders/dustShader.glsl as a soft, ragged, grainy blob.

local dust = {}
package.loaded[...] = dust  -- register now, so modules that require each other share this table

local canvas = require("src.canvas")
local player = require("src.player")
local shader = require("src.shader")
local sprites = require("src.sprites")
local terrain = require("src.terrain")
local water = require("src.water")

local STEP_TIME = 0.12            -- seconds between footsteps while walking
local PUFFS_PER_STEP = 2          -- puffs kicked up by each footstep
local FOOT_SPREAD = 2             -- px either side of his centre
local LIFE_MIN, LIFE_MAX = 0.3, 0.6      -- seconds
local SIZE_START, SIZE_END = 7, 15       -- puff width (px) when kicked up / when gone
local SQUASH = 0.6                -- height / width (puffs hug the ground)
local OPACITY = 0.5              -- at its thickest
local DRIFT = 2                  -- px/s backwards from the way he's walking
local RISE = 5                    -- px/s upward
local COLOUR = { 0.80, 0.72, 0.56 }      -- dry, sandy dust
local LANDING_PUFFS = 4           -- puffs when he lands from a jump

local dot = love.graphics.newImage(love.image.newImageData(1, 1, "rgba8", string.char(255, 255, 255, 255)))

local puffs = {}
local stepTimer, foot = 0, 1
local lastX, lastY, wasOnGround = nil, nil, true

local function spawn(x, y, vx, vy, scale)
    local ground = terrain:surfaceHeight(x, y)
    puffs[#puffs + 1] = {
        x = x, y = y, z = ground, vx = vx, vy = vy,
        age = 0, life = LIFE_MIN + love.math.random() * (LIFE_MAX - LIFE_MIN),
        seed = love.math.random(), scale = scale or 1,
        opacity = OPACITY * (0.7 + 0.3 * love.math.random()),
    }
end

-- Fixed-timestep update: kick up new puffs, age the old ones.
function dust:update(dt)
    local fx, fy = player.x + 16, player.y - 1           -- between his feet
    local moved = lastX ~= nil and (player.x ~= lastX or player.y ~= lastY)
    local dirX = lastX and (player.x - lastX) or 0
    local dirY = lastY and (player.y - lastY) or 0
    lastX, lastY = player.x, player.y

    local onGround = player.isOnGround
    local wet = water:depthAtFeet(fx, player.y - 4, -player.z) > 0

    if player.state == "Walking" and onGround and moved and not wet then
        stepTimer = stepTimer + dt
        if stepTimer >= STEP_TIME then
            stepTimer = stepTimer - STEP_TIME
            foot = -foot
            local len = math.max(1e-6, math.sqrt(dirX * dirX + dirY * dirY))
            local bx, by = -dirX / len, -dirY / len               -- backwards
            -- Feet are side by side across the way he's walking.
            local sideX, sideY = -by * FOOT_SPREAD * foot, bx * FOOT_SPREAD * foot
            for n = 1, PUFFS_PER_STEP do
                local jx, jy = (love.math.random() - 0.5) * 6, (love.math.random() - 0.5) * 3
                spawn(fx + sideX + jx, fy + sideY * 0.5 + jy,
                      bx * DRIFT + (love.math.random() - 0.5) * 6, by * DRIFT * 0.5 + (love.math.random() - 0.5) * 3)
            end
        end
    else
        stepTimer = STEP_TIME * 0.6      -- the first step after starting comes quickly
    end

    if onGround and not wasOnGround and not wet then
        for i = 1, LANDING_PUFFS do
            local a = (i / LANDING_PUFFS + love.math.random() * 0.2) * 2 * math.pi
            spawn(fx + math.cos(a) * 6, fy + math.sin(a) * 3,
                  math.cos(a) * DRIFT * 1.6, math.sin(a) * DRIFT * 0.8, 1.2)
        end
    end
    wasOnGround = onGround

    for i = #puffs, 1, -1 do
        local p = puffs[i]
        p.age = p.age + dt
        if p.age >= p.life then
            table.remove(puffs, i)
        else
            p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
            p.z = p.z + RISE * dt
            p.vx, p.vy = p.vx * 0.96, p.vy * 0.96          -- air slows the drift
        end
    end
end

-- Adds the puffs standing in tile row `row` to that row's draw list.
function dust:addSprites(list, row, cameraX, cameraY)
    local ts = sprites.size
    for _, p in ipairs(puffs) do
        if math.floor(p.y / ts) + 1 == row then
            list[#list + 1] = {
                owner = self, puff = p, tint = 1,          -- lit later, as the ground
                sortY = p.y - cameraY - 0.5, sortX = p.x - cameraX,
                screenX = p.x - cameraX, screenY = p.y - p.z - cameraY,
            }
        end
    end
end

-- Draws one puff onto canvas.object.
function dust:drawItem(item)
    local p = item.puff
    local t = p.age / p.life
    local w = (SIZE_START + (SIZE_END - SIZE_START) * math.sqrt(t)) * p.scale
    local h = math.max(2, w * SQUASH)
    local fade = (1 - t * t) * math.min(1, t * 8)        -- quick in, holds, fades near the end
    local s = shader.dust
    love.graphics.setCanvas(canvas.object)
    love.graphics.setShader(s)
    shader.sendIfPresent(s, "seed", p.seed)
    shader.sendIfPresent(s, "age", t)
    -- The lighting pass blends a sprite pixel in as mix(ground, rgb, alpha),
    -- so the canvas must hold the dust's own colour, not colour x alpha
    -- (which is what normal alpha blending stores and would make it dark).
    -- Premultiplied blending writes the shader's rgb as is.
    love.graphics.setBlendMode("alpha", "premultiplied")
    love.graphics.setColor(COLOUR[1], COLOUR[2], COLOUR[3], p.opacity * fade)
    love.graphics.draw(dot, math.floor(item.screenX - w / 2 + 0.5), math.floor(item.screenY - h + 0.5), 0, w, h)
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setShader()
end

return dust
