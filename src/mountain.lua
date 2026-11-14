-- mountain.lua
--
-- Adds the ART for a tile's south-facing wall to the tile sprite batch: the
-- face of a cliff, or the back wall of a pit. (Lighting/shadow data for
-- walls lives in terrain.lua; this file is only about which sprites to draw.)
--
-- A tile's wall runs from its own height H down to terrain:faceBottom(),
-- which is the lower of ground level and the tile in front of it. It's drawn
-- as a column of 32 px face sprites from the bottom row up. Examples:
--   * a 2-tile cliff on flat ground: wall from 64 down to 0, two rows
--   * the same cliff with a 1-deep pit in front: from 64 down to -32, three rows
--   * a ground tile behind a 1-deep pit: from 0 down to -32 (the pit's back wall)
--
-- SPRITE SHEET LAYOUT (img/sprites2.png, quads numbered left-to-right,
-- top-to-bottom). Face sprites come in four groups of four:
--
--     23-26  a face that is only one tile tall
--     27-30  bottom row of a taller face
--     31-34  middle rows of a taller face
--     35-38  top row of a taller face
--
-- Within each group, add:
--     +1  if the tile to the RIGHT has a wall covering this row
--         (so no right-hand edge/corner should be drawn)
--     +2  if the tile to the LEFT has a wall covering this row (no left edge)
--
-- Quad 45 is a dark gradient stretched over the whole face for depth.

local mountain = {}
package.loaded[...] = mountain  -- register now, so modules that require each other share this table

local sprites = require("src.sprites")
local terrain = require("src.terrain")

local FACE_SINGLE, FACE_BOTTOM, FACE_MIDDLE, FACE_TOP = 23, 27, 31, 35
local FACE_GRADIENT = 45

-- Height (px) of the top of tile (col, row)'s south wall: the highest point
-- of its top's south edge (flat tiles: just their height).
local function wallTop(col, row)
    local k = terrain:cornersOf(col, row)
    return math.max(k[3], k[4])
end

-- Does tile (col, row) have a wall covering the 32 px band starting at
-- height `bandBottom`?
local function wallCovers(col, row, bandBottom)
    local top = wallTop(col, row)
    local bottom = math.min(top, terrain:faceBottom(col, row))
    return top > bandBottom and bottom <= bandBottom
end

-- xC, yC             tile coordinates (1-based)
-- z                  tile's z from mapArray (negative = raised, positive = pit)
-- screenX, screenY   where the tile would be drawn at ground level
-- batch              (optional) sprite batch to add to; default sprites.tileBatch
--
-- SLOPES (terrain.lua): no wall if the tile in front is joined to this one
-- (the ground slants down into it instead). If the top's south edge slants
-- (e.g. the high end of an east-west ramp above lower ground), the wall is
-- drawn one pixel column at a time, each cut off at the edge's height there.
function mountain:add(xC, yC, z, screenX, screenY, batch)
    batch = batch or sprites.tileBatch
    if terrain:joinedSouth(xC, yC) then return end
    local ts = sprites.size
    local k = terrain:cornersOf(xC, yC)
    local top = math.max(k[3], k[4])
    local bottom = terrain:faceBottom(xC, yC)
    if bottom >= top then return end              -- nothing lower in front: no wall

    -- Wall height in whole tiles (rounded up; a partial top row is covered
    -- by the tile's own top, which is drawn after it).
    local rows = math.ceil((top - bottom) / ts - 1e-6)

    -- Which face sprite each row uses. Row 0 is the bottom of the wall,
    -- row rows-1 the top (just under the tile's own surface).
    local quads = {}
    for row = 0, rows - 1 do
        local quad
        if rows == 1 then
            quad = FACE_SINGLE
        elseif row == 0 then
            quad = FACE_BOTTOM
        elseif row == rows - 1 then
            quad = FACE_TOP
        else
            quad = FACE_MIDDLE
        end

        local bandBottom = bottom + row * ts      -- height of this row's lower edge
        if wallCovers(xC + 1, yC, bandBottom) then quad = quad + 1 end
        if wallCovers(xC - 1, yC, bandBottom) then quad = quad + 2 end
        quads[row] = quad
    end
    local gradient = sprites.spritesQuads[FACE_GRADIENT]
    local gradientY = screenY - bottom - (rows - 1) * ts

    if k[3] == k[4] then
        for row = 0, rows - 1 do
            batch:add(sprites.spritesQuads[quads[row]], screenX, screenY - (bottom + row * ts))
        end
        -- Shading gradient over the full wall, stretched to its height.
        batch:add(gradient, screenX, gradientY, 0, 1, rows)
        return
    end

    -- Slanted top edge: column by column, cut at the edge's height.
    for u = 0, ts - 1 do
        local f = (u + 0.5) / ts
        local topU = math.floor(k[3] + (k[4] - k[3]) * f + 0.5)
        if topU > bottom then
            for row = 0, rows - 1 do
                local bandBottom = bottom + row * ts
                if topU > bandBottom then
                    local skip = math.max(0, bandBottom + ts - topU)   -- source rows above the edge
                    sprites.addColumn(batch, sprites.spritesQuads[quads[row]], u, skip,
                        screenX + u, screenY - bandBottom + skip, 1)
                end
            end
            local skipDest = bottom + rows * ts - topU
            sprites.addColumn(batch, gradient, u, skipDest / rows, screenX + u, gradientY + skipDest, rows)
        end
    end
end

-- Screen rectangle a tile covers: its top plus any wall below it. Anything
-- drawn on the object canvas earlier (i.e. further back) inside this area is
-- hidden behind it. Returns x, y, w, h.
function mountain:footprint(xC, yC, z, screenX, screenY)
    local ts = sprites.size
    local k = terrain:cornersOf(xC, yC)
    local top = math.max(k[1], k[2], k[3], k[4], k[5])
    local lowest = math.min(k[3], k[4])
    if not terrain:joinedSouth(xC, yC) then lowest = math.min(lowest, terrain:faceBottom(xC, yC)) end
    return screenX, screenY - top, ts, ts + top - lowest
end

return mountain
