-- tree.lua
--
-- Oak (tile 512) and pine (tile 520) trees. Both live in img/tree4.png as
-- 480x480 quads. Each tree is drawn with the wind-sway shader and casts a
-- shadow that sways in step with its canopy.

local tree = {}
package.loaded[...] = tree  -- register now, so modules that require each other share this table

local canvas = require("src.canvas")
local shader = require("src.shader")
local spriteShadow = require("src.spriteShadow")
local sprites = require("src.sprites")

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
        owner = self, caster = caster, kind = k, swayPx = swayPx,
        sortY = screenY + BASE_IN_TILE_Y, sortX = screenX,
        drawX = screenX + BASE_IN_TILE_X, drawY = screenY + BASE_IN_TILE_Y + z,
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
    love.graphics.setColor(tint, tint, tint, 1)
    love.graphics.draw(sprites.tree, k.quad, item.drawX, item.drawY, 0, 1, 1, k.anchorX, k.anchorY)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setShader()
end

return tree
