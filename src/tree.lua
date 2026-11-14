-- tree.lua
--
-- Oak (tile 512) and pine (tile 520) trees. Both live in img/tree4.png as
-- 480x480 quads. Each tree is drawn with the wind-sway shader and casts a
-- shadow that sways in step with its canopy.

local tree = {}
package.loaded[...] = tree  -- register now, so modules that require each other share this table

local canvas = require("src.canvas")
local player = require("src.player")
local shader = require("src.shader")
local spriteShadow = require("src.spriteShadow")
local sprites = require("src.sprites")
local terrain = require("src.terrain")
local weather = require("src.weather")

local heightQueue = {}   -- trees drawn this frame, for the fog height pass

-- Per kind: which quad, and the point in that quad (anchorX, anchorY) where
-- the tree meets the ground. That point is placed at BASE_IN_TILE inside the
-- tile, so both kinds stand in the same spot.
local KINDS = {
    oak  = { quad = sprites.treeTrunk, anchorX = 240, anchorY = 250 },
    pine = { quad = sprites.pineTree,  anchorX = 244, anchorY = 258 },
}
local BASE_IN_TILE_X, BASE_IN_TILE_Y = 16, 26

-- Wind: max sideways shift at the treetop (px) and speed.
local WIND_PX, WIND_SPEED = 5, 3.0
-- Where the bend starts, as a fraction down the 480 px quad (trunk base ~0.52).
local SWAY_ANCHOR_V = 0.55
-- Height (px above the base) used to decide if a tree is in shadow: mid-canopy.
local TINT_SAMPLE_HEIGHT = 110

-- SEE-THROUGH TREES
-- A tree in front of the player that overlaps him fades to FADE_ALPHA so
-- you can see him (and the ground) behind it, easing in and out at
-- FADE_SPEED (alpha per second). Its shadow is unaffected.
tree.FADE_ALPHA = 1
tree.FADE_SPEED = 4
-- Rough screen-space extent of the canopy around the base point.
local CANOPY_HALF_WIDTH, CANOPY_HEIGHT, CANOPY_BOTTOM = 76, 220, 0

-- Current alpha of each tree that's fading, by tile ("col,row").
local fade = {}

-- Is this tree drawn in front of the player and covering part of him?
local function coversPlayer(item)
    local p, box = player.screenItem, player.screenBox
    if not p or item.sortY <= p.sortY then return false end   -- behind him
    return item.drawX + CANOPY_HALF_WIDTH > box.x0 and item.drawX - CANOPY_HALF_WIDTH < box.x1
       and item.drawY - CANOPY_HEIGHT < box.y1 and item.drawY + CANOPY_BOTTOM > box.y0
end

-- Eases this tree's alpha toward its target and returns it.
local function fadeAlpha(item)
    local target = coversPlayer(item) and tree.FADE_ALPHA or 1
    local a = fade[item.key] or 1
    local step = tree.FADE_SPEED * love.timer.getDelta()
    if a < target then a = math.min(target, a + step) else a = math.max(target, a - step) end
    fade[item.key] = (a < 1) and a or nil       -- forget trees that are fully solid again
    return a
end

-- Called while building the scene (see main.lua). Queues the tree's shadow
-- and adds a draw item to `list`.
function tree:addSprites(list, kind, xC, yC, z, screenX, screenY)
    local k = KINDS[kind]
    local ts = sprites.size
    local qx, qy, qw, qh = k.quad:getViewport()

    local baseX = (xC - 1) * ts + BASE_IN_TILE_X
    local baseY = (yC - 1) * ts + BASE_IN_TILE_Y
    local baseZ = -z

    -- One sway value for this frame, shared by the canopy and its shadow.
    -- The phase differs per tile so neighbouring trees don't move in unison.
    local swayPx = math.sin(love.timer.getTime() * WIND_SPEED + xC * 1.7 + yC * 0.6) * WIND_PX

    local caster = {
        image = sprites.tree, data = sprites.treeData,
        quadX = qx, quadY = qy, quadW = qw, quadH = qh,
        anchorX = k.anchorX, anchorY = k.anchorY,
        worldX = baseX, worldY = baseY, worldZ = baseZ,
        castLamp = true,
        swayPx = swayPx, swayAnchor = SWAY_ANCHOR_V,
    }
    spriteShadow:add(caster)

    list[#list + 1] = {
        owner = self, caster = caster, kind = k, swayPx = swayPx, key = xC .. "," .. yC,
        sortY = screenY + BASE_IN_TILE_Y, sortX = screenX,
        drawX = screenX + BASE_IN_TILE_X, drawY = screenY + BASE_IN_TILE_Y + z,
        baseZ = baseZ,
        tintX = baseX, tintY = baseY, tintZ = baseZ + TINT_SAMPLE_HEIGHT,
    }
end

-- Draws a tree item onto canvas.object with brightness `tint`.
function tree:drawItem(item, tint)
    local k = item.kind
    local qx, qy, qw, qh = k.quad:getViewport()
    local texW, texH = sprites.tree:getDimensions()

    local s = shader.windSway
    love.graphics.setCanvas(canvas.object)
    love.graphics.setShader(s)
    s:send("sway", item.swayPx / texW)
    s:send("quadV0", qy / texH)
    s:send("quadV1", (qy + qh) / texH)
    s:send("anchorV", SWAY_ANCHOR_V)
    love.graphics.setColor(tint, tint, tint, fadeAlpha(item))
    love.graphics.draw(sprites.tree, k.quad, item.drawX, item.drawY, 0, 1, 1, k.anchorX, k.anchorY)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setShader()

    -- Queue it for the height pass (fog only): see tree:drawHeights.
    if weather.fog > 0 then heightQueue[#heightQueue + 1] = item end
end

-- FOG HEIGHTS
-- In fog, each tree pixel is fogged by its real height (the trunk stands in
-- the fog, the canopy rises out of it). The trees drawn this frame are
-- drawn again, in the same order, as the height of each of their pixels
-- into canvas.spriteHeight (treeHeightShader.glsl). Done all at once after
-- the sprites, so it's one canvas switch rather than two per tree.
function tree:drawHeights()
    if #heightQueue == 0 then return end
    local h = shader.treeHeight
    local texW, texH = sprites.tree:getDimensions()
    love.graphics.setCanvas(canvas.spriteHeight)
    love.graphics.setShader(h)
    love.graphics.setBlendMode("replace")
    love.graphics.setColor(1, 1, 1, 1)
    shader.sendIfPresent(h, "heightRange", terrain.heightRange)
    for i, item in ipairs(heightQueue) do
        local k = item.kind
        local _, qy, _, qh = k.quad:getViewport()
        h:send("sway", item.swayPx / texW)
        h:send("quadV0", qy / texH)
        h:send("quadV1", (qy + qh) / texH)
        h:send("anchorV", SWAY_ANCHOR_V)
        shader.sendIfPresent(h, "baseHeight", item.baseZ)
        shader.sendIfPresent(h, "baseScreenY", item.drawY)
        love.graphics.draw(sprites.tree, k.quad, item.drawX, item.drawY, 0, 1, 1, k.anchorX, k.anchorY)
        heightQueue[i] = nil
    end
    love.graphics.setBlendMode("alpha")
    love.graphics.setShader()
end

return tree
