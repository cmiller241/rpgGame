-- tiles.lua
--
-- One place that says what every tile type in mapArray IS: what's drawn on
-- the ground, what sprite stands on it, and what blocks movement. main.lua's
-- scene loop and player collision both read from here, so adding a tile type
-- means adding one entry below.
--
-- A map cell is {type, z, unused}. Types:
--
--     1        grass (with a random decorative flourish)
--     10       tall grass (drawing currently disabled)
--     56       plowed dirt
--     70       wet-soil overlay (only used as a crop layer, never in the map)
--     72-87    crops on dirt: 72/73 seeds ... 86/87 fully grown
--              (even = dry, odd = watered)
--     512      oak tree
--     520      pine tree
--
-- Entry fields:
--     name      for debugging
--     ground    "grass" or "dirt": the base tile drawn under everything
--     flourish  true to scatter a decorative grass sprite on it
--     solid     collision rectangle {x, y, w, h} in px inside the tile
--               (0,0 = top-left), or nil if walkable
--     addSprites(list, xC, yC, z, screenX, screenY, tileType)
--               appends this tile's sprites (trees, crops...) to the row's
--               draw list; see main.lua

local tiles = {}
package.loaded[...] = tiles  -- register now, so modules that require each other share this table

local crop = require("src.crop")
local mapArray = require("src.level").cells
local sprites = require("src.sprites")
local tree = require("src.tree")

-- Trees block only around the trunk, so you can walk behind the canopy.
local TRUNK = { x = 6, y = 18, w = 20, h = 12 }

local types = {}

types[1]   = { name = "grass", ground = "grass", flourish = true }
types[10]  = { name = "tall grass", ground = "grass" }
types[56]  = { name = "plowed dirt", ground = "dirt" }
types[512] = { name = "oak tree", ground = "grass", solid = TRUNK,
               addSprites = function(list, ...) tree:addSprites(list, "oak", ...) end }
types[520] = { name = "pine tree", ground = "grass", solid = TRUNK,
               addSprites = function(list, ...) tree:addSprites(list, "pine", ...) end }

local cropType = { name = "crop", ground = "dirt",
                   addSprites = function(list, ...) crop:addSprites(list, ...) end }
for t = 72, 87 do types[t] = cropType end

-- Anything not listed (e.g. a typo in the map) is drawn as plain grass.
local unknown = { name = "unknown", ground = "grass" }

function tiles.get(tileType)
    return types[tileType] or unknown
end

-- Crop helpers (used by player tools and crop growth).
function tiles.isCrop(t)      return t >= 72 and t <= 87 end
function tiles.isDryCrop(t)   return t >= 72 and t <= 86 and t % 2 == 0 end
function tiles.isWetCrop(t)   return t >= 73 and t <= 87 and t % 2 == 1 end
function tiles.isDirt(t)      return t == 56 or tiles.isCrop(t) end

-- Does the world-space rectangle (x0..x1, y0..y1, inclusive px) overlap a
-- solid part of tile (col, row)? Off-map tiles are fully solid.
function tiles.blocks(col, row, x0, y0, x1, y1)
    local cell = mapArray[row] and mapArray[row][col]
    if not cell then return true end
    local solid = tiles.get(cell[1]).solid
    if not solid then return false end
    local ts = sprites.size
    local sx0 = (col - 1) * ts + solid.x
    local sy0 = (row - 1) * ts + solid.y
    local sx1 = sx0 + solid.w - 1
    local sy1 = sy0 + solid.h - 1
    return x0 <= sx1 and x1 >= sx0 and y0 <= sy1 and y1 >= sy0
end

return tiles
