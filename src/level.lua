-- level.lua
--
-- Loads the map file and turns it into what the engine uses. Map files are
-- written by the map editor (tools/mapeditor/index.html) in "format 2":
--
--   tiles[row][col]    tile type (see tiles.lua)
--   heights[row][col]  ground height in px, positive up
--   blocks             floating blocks: {col, row, underside px}
--   water              starting water: {col, row, depth px}
--   objects            {type = ..., x = ..., y = ..., ...} at pixel positions
--                      ("spawn" = player start, "page" = Bible page, ...)
--
-- What the rest of the game gets:
--   level.cells    the map array: cells[row][col] = {type, z, blockUnderside}
--                  where z = -height (the engine's original convention:
--                  negative = up) and blockUnderside = 0 for no block
--   level.water    starting water entries (poured in by main.lua)
--   level.objects  all objects from the file
--   level.spawn    where the player starts {x, y}

local level = {}
package.loaded[...] = level  -- register now, so modules that require each other share this table

-- Which map to load (a Lua module path, i.e. maps/map01.lua):
--   love .                  maps/map01.lua, the game
--   love . --map NAME       maps/NAME.lua
--   love . --test-map       maps/test.lua, the fixed map the dev tools and
--   love . --shots/--bench  tests are built around (so editing map01 never
--                           breaks them)
local function chosenMap()
    local args = arg or {}
    for i, a in ipairs(args) do
        if a == "--map" and args[i + 1] then return "maps." .. args[i + 1] end
    end
    for _, a in ipairs(args) do
        if a == "--test-map" or a == "--shots" or a == "--bench" then return "maps.test" end
    end
    return "maps.map01"
end
level.file = chosenMap()

local data = require(level.file)
assert(type(data) == "table" and data.format == 2,
    level.file .. " is not a format-2 map; open and re-save it in tools/mapeditor")

level.width, level.height = data.width, data.height

level.cells = {}
for r = 1, data.height do
    local row = {}
    for c = 1, data.width do
        local h = (data.heights[r] and data.heights[r][c]) or 0
        local t = (data.tiles[r] and data.tiles[r][c]) or 1
        row[c] = { t, h == 0 and 0 or -h, 0 }
    end
    level.cells[r] = row
end

for _, b in ipairs(data.blocks or {}) do
    local cell = level.cells[b[2]] and level.cells[b[2]][b[1]]
    if cell then cell[3] = b[3] end
end

level.water = data.water or {}
level.objects = data.objects or {}

-- All objects of one type (copies, so the game can add runtime fields).
function level:objectsOfType(kind)
    local out = {}
    for _, o in ipairs(self.objects) do
        if o.type == kind then
            local copy = {}
            for k, v in pairs(o) do copy[k] = v end
            out[#out + 1] = copy
        end
    end
    return out
end

level.spawn = level:objectsOfType("spawn")[1] or { x = 100, y = 250 }

return level
