-- dirt.lua
--
-- Plowed dirt tiles (tile type 56 and the crop tiles 72-87 sitting on dirt).

local dirt = {}
package.loaded[...] = dirt  -- register now, so modules that require each other share this table

local mapArray = require("src.level").cells
local sprites = require("src.sprites")
local terrain = require("src.terrain")
local tiles = require("src.tiles")

-- Adds a dirt tile to the tile batch. The sprite (quads 56-71) is picked by
-- which neighbours are also dirt, so patches join up seamlessly:
--     +1 up   +2 left   +4 right   +8 down
function dirt:add(xC, yC, z, screenX, screenY, batch)
    batch = batch or sprites.tileBatch
    local tile = 56
    -- (Previously "type >= 56", which also counted trees as dirt.)
    local function isDirt(x, y)
        local cell = mapArray[y] and mapArray[y][x]
        return cell ~= nil and tiles.isDirt(cell[1])
    end

    if isDirt(xC, yC - 1) then tile = tile + 1 end
    if isDirt(xC - 1, yC) then tile = tile + 2 end
    if isDirt(xC + 1, yC) then tile = tile + 4 end
    if isDirt(xC, yC + 1) then tile = tile + 8 end

    sprites.addOnTop(batch, sprites.spritesQuads[tile], screenX, screenY, terrain:cornersOf(xC, yC))
end

return dirt
