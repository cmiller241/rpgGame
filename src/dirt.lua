-- dirt.lua
dirt = {}

function dirt:add(xC, yC, z, zHeight, xTileWidthOffsetX, yTileHeightOffsetY)
    local tempTile = 56 -- Base dirt tile
    local brighten = 1.0

    -- Bitwise checks for adjacent dirt tiles (tile type >= 56)
    if yC > 1 and mapArray[yC-1][xC][1] >= 56 then tempTile = tempTile + 1 end -- Check up
    if xC > 1 and mapArray[yC][xC-1][1] >= 56 then tempTile = tempTile + 2 end -- Check left
    if xC < #mapArray[yC] and mapArray[yC][xC+1][1] >= 56 then tempTile = tempTile + 4 end -- Check right
    if yC < #mapArray and mapArray[yC+1][xC][1] >= 56 then tempTile = tempTile + 8 end -- Check down

    -- Color map the dirt based on height (same as grass)
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

    -- Add dirt tile to sprite batch
    sprites.tileBatch:add(sprites.spritesQuads[tempTile], xTileWidthOffsetX, yTileHeightOffsetY + z)

    -- Delete objects/shadows behind heightened tiles (same as grass)
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