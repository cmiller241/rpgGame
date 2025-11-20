crop={}

function crop:add(xC, yC, z, zHeight, xTileOffset, yTileOffset, cameraX, cameraY, tile)
    local quad
    if tile == 70 then
        quad = sprites.cropQuads[1]  -- Water (first quad)
    else
        -- Crop stages shifted: 72/73→quad[2], 74/75→[3], ..., 86/87→[9]
        local stage = math.floor((tile - 72) / 2) + 2
        quad = sprites.cropQuads[stage]
    end

    local sway = 0
    local noSwayNoShadow = (tile == 70 or tile == 72 or tile == 73)

    if not noSwayNoShadow then
        local time = love.timer.getTime()
        sway = math.sin(time + yC) * 0.08
    end

    -- Batch the crop (always)
    sprites.cropBatch:add(
        quad,
        xTileOffset + 15,
        yTileOffset + z + 27,
        sway,
        1,
        1,
        55,
        85
    )

    -- Batch shadow only for swaying crops (skip for 70 water & 72 seeds)
    if not noSwayNoShadow and shadow.frame == shadow.frequency then
        sprites.cropShadowBatch:add(
            quad,
            xTileOffset + 15,
            yTileOffset + z + 27,
            sway,
            1,
            1,
            55,
            85
        )
    end
end