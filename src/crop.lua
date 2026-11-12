-- crop.lua
--
-- Crops growing on dirt (tile types 72-87) plus the wet-soil overlay (70).
--
-- Tile numbering: each growth stage has a dry (even) and watered (odd) tile,
-- 72/73 = seeds, 74/75 = sprout, ... 86/87 = fully grown.

crop = {}

-- Where the stem meets the soil inside each 112x112 crop quad, and the
-- quad point that's placed at (tile + DRAW_OFFSET).
local ANCHOR_X, ANCHOR_Y = 55, 82
local ORIGIN_X, ORIGIN_Y = 55, 85
local DRAW_OFFSET_X, DRAW_OFFSET_Y = 15, 27

function crop:draw(xC, yC, z, screenX, screenY, tile)
    local ts = sprites.size
    local quad
    if tile == 70 then
        quad = sprites.cropQuads[1]                         -- wet soil
    else
        quad = sprites.cropQuads[math.floor((tile - 72) / 2) + 2]
    end

    -- Water and seeds lie flat: no sway, no shadow.
    local isFlat = (tile == 70 or tile == 72 or tile == 73)
    local sway = isFlat and 0 or math.sin(love.timer.getTime() + yC) * 0.08

    local baseX = (xC - 1) * ts + DRAW_OFFSET_X + (ANCHOR_X - ORIGIN_X)
    local baseY = (yC - 1) * ts + DRAW_OFFSET_Y + (ANCHOR_Y - ORIGIN_Y)
    local baseZ = -z

    local tint = lighting:objectTint(baseX, baseY, baseZ + 16)
    love.graphics.setCanvas(canvas.object)
    love.graphics.setColor(tint, tint, tint, 1)
    love.graphics.draw(sprites.crop, quad,
        screenX + DRAW_OFFSET_X, screenY + z + DRAW_OFFSET_Y, sway, 1, 1, ORIGIN_X, ORIGIN_Y)
    love.graphics.setColor(1, 1, 1, 1)

    if not isFlat then
        local qx, qy, qw, qh = quad:getViewport()
        spriteShadow:add{
            image = sprites.crop,
            quadX = qx, quadY = qy, quadW = qw, quadH = qh,
            anchorX = ANCHOR_X, anchorY = ANCHOR_Y,
            worldX = baseX, worldY = baseY, worldZ = baseZ,
        }
    end
end
