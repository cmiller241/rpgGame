tree = {}

function tree:add(xC, yC, z, zHeight, xTileWidthOffsetX, yTileHeightOffsetY, cameraX, cameraY)
    local time = love.timer.getTime()
    local sway = math.sin(time + yC) * 0.04

    if shadow.frame == shadow.frequency then
        love.graphics.setCanvas(canvas.shadow)
        -- Batch the tree shadow
        sprites.treeShadowBatch:add(
            sprites.treeTrunk,
            xTileWidthOffsetX,
            yTileHeightOffsetY,
            sway,
            1,
            1,
            224,
            224
        )
    end

    -- Batch the tree
    sprites.treeBatch:add(
        sprites.treeTrunk,
        xTileWidthOffsetX,
        yTileHeightOffsetY,
        sway,
        1,
        1,
        224,
        224
    )
end