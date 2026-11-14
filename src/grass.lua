-- grass.lua
--
-- Grass top tiles and the little decorative "flourishes" scattered on them.

local grass = {}
package.loaded[...] = grass  -- register now, so modules that require each other share this table

local mapArray = require("src.level").cells
local sprites = require("src.sprites")
local terrain = require("src.terrain")

-- Adds the grass top for one tile to the tile batch, lifted by its height
-- (and warped to fit if it's on a slope, see terrain.lua SLOPES).
--
-- The base grass sprite (quads 1-8) is picked by which neighbours are NOT a
-- drop, so raised grass gets an edge where it drops off:
--     +1  tile above (north) is not a drop
--     +2  tile to the right is not a drop
--     +4  tile to the left is not a drop
-- A neighbour is a drop if it's lower and not joined to this tile by a slope.
function grass:add(xC, yC, z, screenX, screenY, batch)
    batch = batch or sprites.tileBatch
    local h = -z
    local function noDrop(cell)
        if not cell then return false end
        local nh = -cell[2]
        return nh >= h or terrain:joined(h, nh)
    end
    local tile = 1
    local row = mapArray[yC]
    if yC > 1 and noDrop(mapArray[yC - 1][xC]) then tile = tile + 1 end
    if noDrop(row[xC + 1]) then tile = tile + 2 end
    if noDrop(row[xC - 1]) then tile = tile + 4 end

    sprites.addOnTop(batch, sprites.spritesQuads[tile], screenX, screenY, terrain:cornersOf(xC, yC))
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

function grass:addFlourish(xC, yC, z, screenX, screenY, batch)
    sprites.addOnTop(batch or sprites.tileBatch, sprites.spritesQuads[flourishes[yC][xC]],
        screenX, screenY, terrain:cornersOf(xC, yC))
end

return grass
