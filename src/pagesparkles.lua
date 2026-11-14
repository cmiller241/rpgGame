-- pagesparkles.lua
--
-- Little motes of light dancing around each Bible page: each one circles
-- the page while slowly spiralling upward, weaving in and out a little,
-- twinkling, and fading in at the bottom of its climb and out at the top.
-- When it's on the far side of its circle it's behind the page (smaller,
-- dimmer, and hidden by the page itself); on the near side it's in front.
--
-- They're drawn after the lighting pass (main.lua), straight onto the lit
-- frame with additive blending and shaders/sparkleShader.glsl, so they
-- glow rather than being shaded. Brighter at night (lighting.pageGlow).
--
-- Everything is a function of time, so there's no state to update.

local pageSparkles = {}
package.loaded[...] = pageSparkles  -- register now, so modules that require each other share this table

local canvas = require("src.canvas")
local lighting = require("src.lighting")
local object = require("src.objects")
local shader = require("src.shader")
local terrain = require("src.terrain")
local window = require("src.window")

local MOTES = 4                -- per page
local RADIUS_MIN, RADIUS_MAX = 11, 17   -- px from the page's centre
local DEPTH_SQUASH = 0.55      -- circles are seen from above at an angle: squash front-to-back
local CLIMB = 34               -- px each mote rises over one spiral
local CLIMB_TIME_MIN, CLIMB_TIME_MAX = 3.0, 5.0   -- seconds per spiral
local SPIN_MIN, SPIN_MAX = 1.1, 2.0                -- radians per second around the page
local CENTRE_HEIGHT = 33       -- the page art's centre, px above its ground point (at rest)
local SIZE_FRONT, SIZE_BACK = 9, 7   -- sprite size (px) of a mote in front / behind (glow included)
local COLOUR = { 1.0, 0.9, 0.55 }    -- warm gold
local DAY_STRENGTH = 0.8       -- brightness in full daylight (night = 1)

-- One white texel, stretched into each mote's square (the shader rounds it).
local dot = love.graphics.newImage(love.image.newImageData(1, 1, "rgba8", string.char(255, 255, 255, 255)))
local batchFront = love.graphics.newSpriteBatch(dot, 128, "stream")
local batchBack = love.graphics.newSpriteBatch(dot, 128, "stream")
local sparkleShader = shader.sparkle

-- A repeatable pseudo-random number 0..1 for (a, b, c).
local function hash(a, b, c)
    local v = math.sin(a * 12.9898 + b * 78.233 + c * 37.719) * 43758.5453
    return v - math.floor(v)
end
local function between(lo, hi, t) return lo + (hi - lo) * t end

-- Queues the motes of one page (world position x, y = its ground point).
local function addPage(obj, t, cameraX, cameraY, strength)
    local gx, gy = obj.x, obj.y - 4
    local ground = terrain:heightAtWorld(gx, gy)
    local bob = math.sin(obj.animationTime * 2 * math.pi) * 4      -- as in objects.lua
    local centre = ground + CENTRE_HEIGHT - bob
    for j = 1, MOTES do
        local h1, h2, h3, h4 = hash(gx, gy, j), hash(gy, j, gx), hash(j, gx * 0.5, gy), hash(j * 3, gy, gx * 0.3)
        local dir = h4 < 0.35 and -1 or 1                          -- a few go the other way
        local spin = between(SPIN_MIN, SPIN_MAX, h1) * dir
        local angle = h2 * 6.283 + spin * t + 0.45 * math.sin(t * 1.7 + h3 * 9)   -- weaving
        local radius = between(RADIUS_MIN, RADIUS_MAX, h3) * (0.85 + 0.15 * math.sin(t * 1.3 + h1 * 7))
        local climb = (t / between(CLIMB_TIME_MIN, CLIMB_TIME_MAX, h4) + h1) % 1
        local height = centre - CLIMB / 2 + climb * CLIMB + 2 * math.sin(t * 2.3 + h2 * 5)
        local fade = math.sin(climb * math.pi)                    -- in at the bottom, out at the top
        local twinkle = 0.7 + 0.3 * math.sin(t * 6 + h3 * 20)

        local depth = math.sin(angle)                              -- < 0: the far side (behind)
        local wx = gx + math.cos(angle) * radius
        local wy = gy + depth * radius * DEPTH_SQUASH
        local sx = math.floor(wx - cameraX + 0.5)
        local sy = math.floor(wy - height - cameraY + 0.5)

        local isBehind = depth < 0
        local size = isBehind and SIZE_BACK or SIZE_FRONT
        local a = fade * twinkle * strength * (isBehind and 0.6 or 1)
        local batch = isBehind and batchBack or batchFront
        batch:setColor(COLOUR[1], COLOUR[2], COLOUR[3], a)
        batch:add(sx - math.floor(size / 2), sy - math.floor(size / 2), 0, size, size)
    end
end

-- Draws every on-screen page's motes onto canvas.intermediate (the lit
-- frame). Call right after lighting:composite.
function pageSparkles:draw(cameraX, cameraY)
    batchFront:clear()
    batchBack:clear()
    local t = love.timer.getTime()
    local night = lighting.sun and lighting.sun.night or 0
    local strength = DAY_STRENGTH + (1 - DAY_STRENGTH) * night
    local margin = 64
    for _, obj in ipairs(object.objects) do
        local sx, sy = obj.x - cameraX, obj.y - cameraY
        if sx > -margin and sx < window.width + margin and sy > -margin and sy < window.height + margin * 2 then
            addPage(obj, t, cameraX, cameraY, strength)
        end
    end
    if batchFront:getCount() + batchBack:getCount() == 0 then return end

    love.graphics.setCanvas(canvas.intermediate)
    love.graphics.setShader(sparkleShader)
    shader.sendIfPresent(sparkleShader, "objectCanvas", canvas.object)
    shader.sendIfPresent(sparkleShader, "screenSize", { window.width, window.height })
    love.graphics.setBlendMode("add")
    love.graphics.setColor(1, 1, 1, 1)
    shader.sendIfPresent(sparkleShader, "behind", true)
    love.graphics.draw(batchBack)
    shader.sendIfPresent(sparkleShader, "behind", false)
    love.graphics.draw(batchFront)
    love.graphics.setBlendMode("alpha")
    love.graphics.setShader()
end

return pageSparkles
