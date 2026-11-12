-- grass.lua
--
-- Grass top tiles and the little decorative "flourishes" scattered on them.

local grass = {}
package.loaded[...] = grass  -- register now, so modules that require each other share this table

local mapArray = require("maps.map01")
local sprites = require("src.sprites")

-- Adds the grass top for one tile to the tile batch, lifted by its height.
--
-- The base grass sprite (quads 1-8) is picked by which neighbours are at the
-- same height or lower, so raised grass gets an edge where it drops off:
--     +1  tile above (north) is not higher
--     +2  tile to the right is not higher
--     +4  tile to the left is not higher
function grass:add(xC, yC, z, screenX, screenY)
    local tile = 1
    local row = mapArray[yC]
    if yC > 1 and mapArray[yC - 1][xC] and mapArray[yC - 1][xC][2] <= z then tile = tile + 1 end
    if row[xC + 1] and row[xC + 1][2] <= z then tile = tile + 2 end
    if row[xC - 1] and row[xC - 1][2] <= z then tile = tile + 4 end

    sprites.tileBatch:add(sprites.spritesQuads[tile], screenX, screenY + z)
end

-- Which flourish sprite (quads 11-22) each tile gets. Worked out once at load
-- instead of reseeding Lua's random generator for every tile every frame.
-- Uses the same seed formula as before, so the pattern is unchanged.
local flourishes = {}

function grass:buildFlourishes()
    for yC = 1, #mapArray do
        flourishes[yC] = {}
        for xC = 1, #mapArray[yC] do
            math.randomseed(yC * xC * 2000)
            flourishes[yC][xC] = math.floor(math.random() * 12 + 1) + 10
        end
    end
    math.randomseed(os.time()) -- don't leave the global generator predictable
end

function grass:addFlourish(xC, yC, z, screenX, screenY)
    sprites.tileBatch:add(sprites.spritesQuads[flourishes[yC][xC]], screenX, screenY + z)
end

return grass
