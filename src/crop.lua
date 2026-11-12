-- crop.lua
--
-- Crops growing on dirt (tile types 72-87) plus the wet-soil overlay (70).
--
-- Tile numbering: each growth stage has a dry (even) and watered (odd) tile,
-- 72/73 = seeds, 74/75 = sprout, ... 86/87 = fully grown.

local crop = {}
package.loaded[...] = crop  -- register now, so modules that require each other share this table

local canvas = require("src.canvas")
local spriteShadow = require("src.spriteShadow")
local sprites = require("src.sprites")
local tiles = require("src.tiles")

-- Where the stem meets the soil inside each 112x112 crop quad, and the
-- quad point that's placed at (tile + DRAW_OFFSET).
local ANCHOR_X, ANCHOR_Y = 55, 82
local ORIGIN_X, ORIGIN_Y = 55, 85
local DRAW_OFFSET_X, DRAW_OFFSET_Y = 15, 27

-- Called while building the scene (see main.lua). Adds the wet-soil overlay
-- (for watered tiles) and the plant itself, and queues the plant's shadow.
function crop:addSprites(list, xC, yC, z, screenX, screenY, tile)
    if tiles.isWetCrop(tile) then
        self:addLayer(list, xC, yC, z, screenX, screenY, 70, screenY + 23)
    end
    self:addLayer(list, xC, yC, z, screenX, screenY, tile, screenY + 24)
end

function crop:addLayer(list, xC, yC, z, screenX, screenY, tile, sortY)
    local ts = sprites.size
    local quad
    if tile == 70 then
        quad = sprites.cropQuads[1]                         -- wet soil
    else
        quad = sprites.cropQuads[math.floor((tile - 72) / 2) + 2]
    end

    -- Water and seeds lie flat: no sway, no shadow.
    local isFlat = (tile == 70 or tile == 72 or tile == 73)

    local baseX = (xC - 1) * ts + DRAW_OFFSET_X + (ANCHOR_X - ORIGIN_X)
    local baseY = (yC - 1) * ts + DRAW_OFFSET_Y + (ANCHOR_Y - ORIGIN_Y)
    local baseZ = -z

    local caster
    if not isFlat then
        local qx, qy, qw, qh = quad:getViewport()
        caster = {
            image = sprites.crop, data = sprites.cropData,
            quadX = qx, quadY = qy, quadW = qw, quadH = qh,
            anchorX = ANCHOR_X, anchorY = ANCHOR_Y,
            worldX = baseX, worldY = baseY, worldZ = baseZ,
        }
        spriteShadow:add(caster)
    end

    list[#list + 1] = {
        owner = self, caster = caster, quad = quad,
        sway = isFlat and 0 or math.sin(love.timer.getTime() + yC) * 0.08,
        sortY = sortY, sortX = screenX,
        drawX = screenX + DRAW_OFFSET_X, drawY = screenY + z + DRAW_OFFSET_Y,
        tintX = baseX, tintY = baseY, tintZ = baseZ + 16,
    }
end

function crop:drawItem(item, tint)
    love.graphics.setCanvas(canvas.object)
    love.graphics.setColor(tint, tint, tint, 1)
    love.graphics.draw(sprites.crop, item.quad, item.drawX, item.drawY, item.sway, 1, 1, ORIGIN_X, ORIGIN_Y)
    love.graphics.setColor(1, 1, 1, 1)
end

return crop
