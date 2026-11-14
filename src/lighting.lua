-- lighting.lua
--
-- Per-frame light state (sun + the player's lamp) and the final composite
-- pass that turns the ground, sprite and shadow canvases into the finished
-- frame. The heavy lifting is in shaders/ultimateShader.glsl.

local lighting = {}
package.loaded[...] = lighting  -- register now, so modules that require each other share this table

local canvas = require("src.canvas")
local clouds = require("src.clouds")
local object = require("src.objects")
local player = require("src.player")
local shader = require("src.shader")
local spriteShadow = require("src.spriteShadow")
local sprites = require("src.sprites")
local sun = require("src.sun")
local terrain = require("src.terrain")
local water = require("src.water")
local weather = require("src.weather")

lighting.lampRadius = 100     -- px, how far the player's lamp reaches
lighting.lampHeight = 24      -- px above the player's feet (roughly hand height)

-- BIBLE PAGES GIVE OFF LIGHT
-- Up to PAGE_LIGHTS pages nearest the player each light a warm pool around
-- them (blocked by terrain, like the lamp). Their glow is faint by day and
-- full at night (pageGlowDay .. 1, by sun.night).
lighting.PAGE_LIGHTS   = 6         -- must match MAX_PAGE_LIGHTS in ultimateShader.glsl
lighting.pageRadius    = 80        -- px
lighting.pageHeight    = 20        -- px above the ground (the page hovers)
lighting.pageGlowDay   = 0.25      -- glow strength in full daylight (night = 1)
lighting.pageTint      = { 1.25, 1.1, 0.75 }   -- warm candle-like colour
-- The light pulses with the page's hover (it bobs 4 px up and down once a
-- second, objects.lua): at the top of the bob the pool is this much wider
-- and brighter, at the bottom this much smaller and dimmer.
lighting.pagePulseRadius = 0.08    -- +/- 8 % radius
lighting.pagePulsePower  = 0.15    -- +/- 15 % brightness

-- How visible the player's silhouette is through terrain that hides him
-- (pit rims, cliffs in front of him). 0 turns the ghost off.
lighting.ghostOpacity = 0.2

-- PIT FOCUS
-- While the player stands below ground level (in a pit), the pit gets the
-- attention:
--   * higher terrain that hides part of the pit (e.g. its front rim) turns
--     partly see-through, showing the pit floor and the player under it;
--   * all other terrain and sprites above his level are dimmed a little.
-- The tiles at/below his level are rendered as a separate layer for this
-- (main.lua, terrain:drawFocusSurface). Eases in and out.
lighting.focusRevealOpacity = 0.5     -- how much of the pit shows through higher ground (0..1)
lighting.focusPlayerOpacity = 0.85    -- how much of the player shows through it (0..1)
lighting.focusDim           = 0.2     -- how much darker/greyer everything above his level gets (0..1)
lighting.focusFadeTime      = 0.25    -- seconds to ease in / out

-- Current focus state (updated in lighting:begin).
lighting.focus = { amount = 0, level = 0 }

-- Filled in by lighting:begin() each frame.
lighting.sun = nil
lighting.lamp = { x = 0, y = 0, z = 0, radius = lighting.lampRadius }

-- Call once at the start of love.draw, before any sprites are drawn.
function lighting:begin()
    self.sun = weather:overcast(sun:getState())   -- rain dims the sun (and its shadows)

    -- Pit focus: on while the ground under him is below ground level. When he
    -- climbs out, keep the old level until the effect has faded away.
    local focus = self.focus
    local groundLevel = -player.shadowZ
    if groundLevel < 0 then focus.level = groundLevel end
    local target = (groundLevel < 0) and 1 or 0
    local step = love.timer.getDelta() / math.max(self.focusFadeTime, 1e-6)
    if focus.amount < target then
        focus.amount = math.min(target, focus.amount + step)
    else
        focus.amount = math.max(target, focus.amount - step)
    end

    -- The lamp sits at the player's feet position on the ground plane, raised
    -- to hand height. player.z is negative-up, so -player.z is the height.
    local lamp = self.lamp
    lamp.x = player.drawX + 16
    lamp.y = player.drawY - 4
    lamp.z = -player.drawZ + self.lampHeight
    lamp.radius = self.lampRadius

    -- The pages nearest the player, as lights: {x, y, z, radius}, plus
    -- power (brightness). Each rises and falls with its page's hover.
    local pages = {}
    for _, obj in ipairs(object.objects) do
        local gx, gy = obj.x, obj.y - 4
        local dx, dy = gx - lamp.x, gy - lamp.y
        local bob = math.sin(obj.animationTime * 2 * math.pi) * 4   -- as in objects.lua (+ = lower)
        local rise = -bob / 4                                       -- -1 at the bottom, 1 at the top
        pages[#pages + 1] = { gx, gy, terrain:heightAtWorld(gx, gy) + self.pageHeight - bob,
                              self.pageRadius * (1 + self.pagePulseRadius * rise),
                              power = 1 + self.pagePulsePower * rise,
                              dist = dx * dx + dy * dy }
    end
    table.sort(pages, function(a, b) return a.dist < b.dist end)
    for i = #pages, self.PAGE_LIGHTS + 1, -1 do pages[i] = nil end
    self.pageLights = pages
    self.pageGlow = self.pageGlowDay + (1 - self.pageGlowDay) * (self.sun.night or 0)
end

-- Brightness multiplier for a sprite sampled at world (wx, wy), height h:
-- the same lit/shadow level the shader gives the ground, so sprites darken
-- in a cliff's shadow or another sprite's shadow (e.g. under a tree) and
-- fade into dusk along with everything else. `ownCaster` is the sprite's own
-- shadow caster, so it doesn't shadow itself. Use with love.graphics.setColor.
function lighting:objectTint(wx, wy, h, ownCaster)
    local sunState = self.sun
    if sunState.litLevel <= sunState.shadowLevel then
        return sunState.litLevel                 -- no direct sun to block
    end
    local shade = terrain:sunShadowAmount(wx, wy, h, sunState)
    if shade < 1 then
        shade = math.max(shade, spriteShadow:sunShadowAt(wx, wy, h, ownCaster, sunState))
    end
    if shade < 1 then
        shade = math.max(shade, clouds:shadowAt(wx, wy, h, sunState))
    end
    return sunState.litLevel + (sunState.shadowLevel - sunState.litLevel) * shade
end

-- Composites canvas.offscreen (+ object/shadow canvases) into
-- canvas.intermediate with lighting, shadows and colour grading applied.
function lighting:composite(cameraX, cameraY)
    local s, sunState, lamp = shader.ultimate, self.sun, self.lamp

    love.graphics.setCanvas(canvas.intermediate)
    love.graphics.setShader(s)

    terrain:sendUniforms(s, cameraX, cameraY)
    s:send("objectCanvas", canvas.object)
    s:send("shadowCanvas", canvas.shadow)
    s:send("xrayCanvas", canvas.xray)
    s:send("ghostOpacity", self.ghostOpacity)

    s:send("focusCanvas", canvas.focus)
    s:send("focusSurfaceMap", canvas.focusSurface)
    s:send("focusAmount", self.focus.amount)
    s:send("focusLevel", self.focus.level)
    s:send("focusRevealOpacity", self.focusRevealOpacity)
    s:send("focusPlayerOpacity", self.focusPlayerOpacity)
    s:send("focusDim", self.focusDim)
    s:send("time", love.timer.getTime())
    s:send("waterMap", water.map)

    -- Player in water: how deep it is at his feet, and where the surface
    -- line falls on screen (his feet are 4 px above player.y in the art).
    local feetScreenY = player.drawY - 4 + player.drawZ - cameraY
    local depthAtFeet = water:depthAtFeet(player.drawX + 16, player.drawY - 4, -player.drawZ)
    s:send("playerWaterDepth", depthAtFeet)
    s:send("playerWaterLine", feetScreenY - depthAtFeet)

    s:send("sunDir", {sunState.dirX, sunState.dirY})
    s:send("sunSlope", sunState.slope)
    s:send("sunSoftness", sunState.softness)
    s:send("litLevel", sunState.litLevel)
    s:send("shadowLevel", sunState.shadowLevel)
    s:send("faceLight", sunState.faceLight)

    s:send("lampPos", {lamp.x, lamp.y, lamp.z})
    s:send("lampScreen", {lamp.x - cameraX, lamp.y - lamp.z - cameraY})
    s:send("lampRadius", lamp.radius)

    -- Pages as lights (world position + radius, and where they are on screen).
    local send = shader.sendIfPresent
    local pages = self.pageLights or {}
    send(s, "pageLightCount", #pages)
    if #pages > 0 then
        local screen = {}
        local power = {}
        for i, pg in ipairs(pages) do
            screen[i] = { pg[1] - cameraX, pg[2] - pg[3] - cameraY }
            power[i] = pg.power
        end
        send(s, "pageLights", unpack(pages))
        send(s, "pageLightScreen", unpack(screen))
        send(s, "pageLightPower", unpack(power))
    end
    send(s, "pageGlow", self.pageGlow or 0)
    send(s, "pageTint", self.pageTint)

    clouds:sendUniforms(s, send)

    -- For water reflections: the ground tiles alone, and the player's feet
    -- (world y) so he can be reflected.
    send(s, "weatherAmount", weather.amount)
    send(s, "lightningFlash", weather.flash)
    send(s, "fogAmount", weather.fog)
    send(s, "fogDrift", weather.fogDrift)
    send(s, "spriteHeightMap", canvas.spriteHeight)
    send(s, "playerFeetScreenY", feetScreenY)
    send(s, "playerFeetHeight", -player.drawZ)
    send(s, "weatherTint", weather.tint)
    send(s, "weatherDesaturate", weather.desaturate)
    send(s, "groundCanvas", canvas.offscreen)
    send(s, "playerFeetY", player.drawY - 4)
    send(s, "waterReflections", true)

    s:send("lutImage", sprites.lut)
    s:send("lutSize", {sprites.lut:getDimensions()})
    s:send("lutRowA", sunState.lutRowA)
    s:send("lutRowB", sunState.lutRowB)
    s:send("lutMix", sunState.lutMix)

    love.graphics.draw(canvas.offscreen, 0, 0)
    love.graphics.setShader()
end

return lighting
