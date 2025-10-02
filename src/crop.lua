crop = {}

function crop:add(xC, yC, z, zHeight, xTileOffset, yTileOffset, cameraX, cameraY, tile)
    local quad = sprites.spritesQuads[tile]

    if shadow.frame == shadow.frequency then
        -- Batch the crop shadow
        sprites.cropShadowBatch:add(
            quad,
            xTileOffset,
            yTileOffset + z,
            0,
            1,
            1,
            0,  -- ox: adjust based on your crop sprite width/2
            0  -- oy: adjust based on your crop sprite height
        )
    end

    -- Batch the crop
    sprites.cropBatch:add(
        quad,
        xTileOffset,
        yTileOffset + z,
        0,
        1,
        1,
        0,  -- ox: adjust based on your crop sprite width/2
        0  -- oy: adjust based on your crop sprite height
    )
end