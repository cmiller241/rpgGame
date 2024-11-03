-- grass.lua
mountain = {}

function mountain:add(xC, yC, z, zHeight, xTileWidthOffsetX, yTileHeightOffsetY)
    local gradientGleam = 3

    for i = 0, zHeight + 1, -1 do
        local mSprite = 23

        --Bitwising time!
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
        local occluder = 0                      --Color Map the Mountain
        local face = 1
        local level = (i - 1) * -0.1
        if mapArray[yC + i][xC][2] < 0 then     --If tile behind mountain is occluder...
            occluder = 1                        --the tile space should remain an occluder
            level = 0.1     --Level needs to be ground. But this will need to be adjusted.
        end
        if mapArray[yC + 1][xC][2] > z          --If tile in front of mountain is lower...  
            and mapArray[yC+1][xC][2] <= z + sprites.size then     --But not by too much...
            occluder = 1                        --Then it's an occluder. 
            level = (i - 1) * -0.1
        end 
        if mapArray[yC + 1][xC+1][2] > z          --If tile in front of mountain is lower...  
            and mapArray[yC+1][xC+1][2] <= z + sprites.size then     --But not by too much...
            occluder = 1                        --Then it's an occluder. 
            level = (i - 1) * -0.1
        end 
        if mapArray[yC][xC+1][2] > z          --If tile in front of mountain is lower...  
            and mapArray[yC][xC+1][2] <= z + sprites.size then     --But not by too much...
            occluder = 1                        --Then it's an occluder. 
            level = (i - 1) * -0.1
        end 
        if (i == 0) then occluder = 1 end
        love.graphics.setColor(face,occluder,level)
        love.graphics.setCanvas(canvas.colorMap)
        love.graphics.rectangle(
            "fill",
            xTileWidthOffsetX,
            yTileHeightOffsetY + i*sprites.size,
            sprites.size,
            sprites.size
        )

        --Delete shadows and objects behind mountain face

        love.graphics.setColor(0,0,0,0)
        love.graphics.setBlendMode('replace')
        if shadow.frame == shadow.frequency then 
            love.graphics.setCanvas(canvas.shadow)
            love.graphics.rectangle(
                "fill",
                xTileWidthOffsetX,
                yTileHeightOffsetY + i * sprites.size,
                sprites.size,
                sprites.size
            )
        end

        love.graphics.setCanvas(canvas.object)
        love.graphics.rectangle(
            'fill',
            xTileWidthOffsetX,
            yTileHeightOffsetY + i * sprites.size,
            sprites.size,
            sprites.size
        )
        love.graphics.setBlendMode('alpha')
        love.graphics.setColor(1,1,1,1)
    end
    mountain:addGradient(xC, yC, z, zHeight, xTileWidthOffsetX, yTileHeightOffsetY)
end

-- Function to add a gradient based on tile height and position
function mountain:addGradient(x, y, z, zHeight, xTileWidthOffsetX, yTileHeightOffsetY)
    -- Calculate transparency based on the height position of the tile
    local maxTransparency = 0.8  -- Maximum transparency for the bottom tile
    local minTransparency = 0.2  -- Minimum transparency for the top tile
    local transparencyStep = (maxTransparency - minTransparency) / zHeight

    -- Add gradient sprite to the batch
    sprites.tileBatch:add(sprites.spritesQuads[45], xTileWidthOffsetX, yTileHeightOffsetY + (zHeight+1) * sprites.size, 0, 1, zHeight*-1, 0, 0)
end

-- Helper function to check if a tile is an occluder
function mountain:isOccluder(tileZ, neighborZ, size)
    return neighborZ < 0 or (tileZ > neighborZ and neighborZ <= tileZ + size)
end