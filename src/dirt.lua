-- dirt.lua
--
-- Plowed dirt tiles (tile type 56 and the crop tiles 72-87 sitting on dirt).

dirt = {}

-- Adds a dirt tile to the tile batch. The sprite (quads 56-71) is picked by
-- which neighbours are also dirt, so patches join up seamlessly:
--     +1 up   +2 left   +4 right   +8 down
function dirt:add(xC, yC, z, screenX, screenY)
    local tile = 56
    local function isDirt(x, y)
        local cell = mapArray[y] and mapArray[y][x]
        return cell ~= nil and cell[1] >= 56
    end

    if isDirt(xC, yC - 1) then tile = tile + 1 end
    if isDirt(xC - 1, yC) then tile = tile + 2 end
    if isDirt(xC + 1, yC) then tile = tile + 4 end
    if isDirt(xC, yC + 1) then tile = tile + 8 end

    sprites.tileBatch:add(sprites.spritesQuads[tile], screenX, screenY + z)
end
