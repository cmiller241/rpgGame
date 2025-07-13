mountain = {}

function mountain:add(xC, yC, z, zHeight, xTileWidthOffsetX, yTileHeightOffsetY)
    local gradientGleam = 3
    local shadowClearAreas = {}
    local objectClearAreas = {}

    for i = 0, zHeight + 1, -1 do
        local mSprite = 23

        -- Bitwising time!
        if (mapArray[yC][xC+1][2] / sprites.size < i) then
            mSprite = mSprite + 1
        end
        if (mapArray[yC][xC-1][2] / sprites.size < i) then
            mSprite = mSprite + 2
            gradientGleam = 0
        end
        if (zHeight < -1) then mSprite = mSprite + 4 end
        if (i ~= 0 and i ~= zHeight) then mSprite = mSprite + 4 end
        if (i == zHeight + 1 and i ~= 0) then mSprite = mSprite + 4 end

        sprites.tileBatch:add(sprites.spritesQuads[mSprite], xTileWidthOffsetX, yTileHeightOffsetY + i * sprites.size)

        -- Add the mountain to the color map (for shadowing)
        local occluder = 0
        local face = 1
        local level = (i - 1) * -0.1
        if mapArray[yC + i][xC][2] < 0 then
            occluder = 1
            level = 0.1
        end
        if mapArray[yC + 1][xC][2] > z and mapArray[yC+1][xC][2] <= z + sprites.size then
            occluder = 1
            level = (i - 1) * -0.1
        end
        if mapArray[yC + 1][xC+1][2] > z and mapArray[yC+1][xC+1][2] <= z + sprites.size then
            occluder = 1
            level = (i - 1) * -0.1
        end
        if mapArray[yC][xC+1][2] > z and mapArray[yC][xC+1][2] <= z + sprites.size then
            occluder = 1
            level = (i - 1) * -0.1
        end
        if i == 0 then occluder = 1 end
        love.graphics.setColor(face, occluder, level)
        love.graphics.setCanvas(canvas.colorMap)
        love.graphics.rectangle(
            "fill",
            xTileWidthOffsetX,
            yTileHeightOffsetY + i * sprites.size,
            sprites.size,
            sprites.size
        )

        -- Collect areas to clear for shadows and objects
        if shadow.frame == shadow.frequency then
            table.insert(shadowClearAreas, {
                x = xTileWidthOffsetX,
                y = yTileHeightOffsetY + i * sprites.size,
                width = sprites.size,
                height = sprites.size
            })
        end
        table.insert(objectClearAreas, {
            x = xTileWidthOffsetX,
            y = yTileHeightOffsetY + i * sprites.size,
            width = sprites.size,
            height = sprites.size
        })
    end

    -- Batch clear shadow canvas areas
    if shadow.frame == shadow.frequency and #shadowClearAreas > 0 then
        love.graphics.setColor(0, 0, 0, 0)
        love.graphics.setBlendMode('replace')
        love.graphics.setCanvas(canvas.shadow)
        for _, area in ipairs(shadowClearAreas) do
            love.graphics.rectangle("fill", area.x, area.y, area.width, area.height)
        end
        love.graphics.setBlendMode('alpha')
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- Batch clear object canvas areas
    if #objectClearAreas > 0 then
        love.graphics.setColor(0, 0, 0, 0)
        love.graphics.setBlendMode('replace')
        love.graphics.setCanvas(canvas.object)
        for _, area in ipairs(objectClearAreas) do
            love.graphics.rectangle("fill", area.x, area.y, area.width, area.height)
        end
        love.graphics.setBlendMode('alpha')
        love.graphics.setColor(1, 1, 1, 1)
    end

    mountain:addGradient(xC, yC, z, zHeight, xTileWidthOffsetX, yTileHeightOffsetY)
end

function mountain:addGradient(x, y, z, zHeight, xTileWidthOffsetX, yTileHeightOffsetY)
    local maxTransparency = 0.8
    local minTransparency = 0.2
    local transparencyStep = (maxTransparency - minTransparency) / zHeight

    sprites.tileBatch:add(sprites.spritesQuads[45], xTileWidthOffsetX, yTileHeightOffsetY + (zHeight+1) * sprites.size, 0, 1, zHeight*-1, 0, 0)
end

function mountain:isOccluder(tileZ, neighborZ, size)
    return neighborZ < 0 or (tileZ > neighborZ and neighborZ <= tileZ + size)
end