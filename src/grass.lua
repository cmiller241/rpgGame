-- grass.lua
grass = {}

function grass:add(xC, yC, z, zHeight, xTileWidthOffsetX, yTileHeightOffsetY)
    local tempTile = 1
    local brighten = 1.0

    -- Bitwising Time (if the grass is elevated it will have different edges)
    if yC > 1 and mapArray[yC-1][xC][2] <= z then tempTile = tempTile + 1 end  -- Check top edge
    if xC < #mapArray[yC] and mapArray[yC][xC+1][2] <= z then tempTile = tempTile + 2 end  -- Check right edge
    if xC > 1 and mapArray[yC][xC-1][2] <= z then tempTile = tempTile + 4 end  -- Check left edge
    
    --Color map the grass based on height
    if z < 0 then
        local occluder = 0
        local face = 0
        local level = (zHeight * -0.1)
        love.graphics.setColor(face, occluder, level)
        love.graphics.setCanvas(canvas.colorMap)
        love.graphics.rectangle("fill", xTileWidthOffsetX, yTileHeightOffsetY + z, sprites.size, sprites.size)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setCanvas(canvas.offscreen)
    end

    sprites.tileBatch:add(sprites.spritesQuads[tempTile], xTileWidthOffsetX, yTileHeightOffsetY + z)

    -- Delete objects / shadows behind heightened tiles
    if z < 0 then
        love.graphics.setColor(0, 0, 0, 0)
        love.graphics.setBlendMode('replace')
        love.graphics.setCanvas(canvas.object)
        love.graphics.rectangle('fill', xTileWidthOffsetX, yTileHeightOffsetY + z, sprites.size, sprites.size)
        
        if shadow.frame == shadow.frequency then
            love.graphics.setCanvas(canvas.shadow)
            love.graphics.rectangle('fill', xTileWidthOffsetX, yTileHeightOffsetY + z, sprites.size, sprites.size)
        end
        
        love.graphics.setBlendMode('alpha')
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setCanvas(canvas.offscreen)
    end
end

function grass:addFlourish(xC, yC, z, zHeight, xTileWidthOffsetX, yTileHeightOffsetY)
    -- Add grass flourish
    local seed = yC * xC * 2000
    math.randomseed(seed)
    local randomValue = math.random()
    local hash = math.floor(randomValue * 12 + 1)
    hash = hash + 10

    if hash < 1 then hash = 12 end
    if hash > 220 then hash = 12 end

    sprites.tileBatch:add(sprites.spritesQuads[hash], xTileWidthOffsetX, yTileHeightOffsetY + z)
end
