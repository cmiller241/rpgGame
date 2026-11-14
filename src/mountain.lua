-- mountain.lua
--
-- Adds the ART for a tile's south-facing wall to the tile sprite batch: the
-- face of a cliff, or the back wall of a pit. (Lighting/shadow data for
-- walls lives in terrain.lua; this file is only about which sprites to draw.)
--
-- A tile's wall runs from its own height H down to terrain:faceBottom(),
-- which is the lower of ground level and the tile in front of it. It's drawn
-- as a column of 32 px face sprites stacked down from its top (so the top
-- piece, whose grass tufts over the edge, is always flush with it). Examples:
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

    -- Wall height in whole 32 px pieces, rounded up. The pieces are stacked
    -- DOWN FROM THE TOP, so the top piece (with the grass tufting over the
    -- edge) always sits flush with the wall's top, whatever its height. When
    -- the height isn't a whole number of pieces, the lowest piece hangs below
    -- the wall's foot, where the tile in front (drawn later) covers it.
    -- (Whole-tile walls come out exactly as stacking up from the bottom.)
    local rows = math.ceil((top - bottom) / ts - 1e-6)

    -- Which face sprite each piece uses. Piece 0 is the lowest, piece
    -- rows-1 the top one, just under the tile's own surface.
    local function bandBottomOf(row, wallTop, count) return wallTop - (count - row) * ts end
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

        local bandBottom = bandBottomOf(row, top, rows)    -- height of this piece's lower edge
        if wallCovers(xC + 1, yC, bandBottom) then quad = quad + 1 end
        if wallCovers(xC - 1, yC, bandBottom) then quad = quad + 2 end
        quads[row] = quad
    end
    local gradient = sprites.spritesQuads[FACE_GRADIENT]

    if k[3] == k[4] then
        for row = 0, rows - 1 do
            batch:add(sprites.spritesQuads[quads[row]], screenX, screenY - bandBottomOf(row, top, rows))
        end
        -- Shading gradient over the full wall (from its top), stretched to its height.
        batch:add(gradient, screenX, screenY + ts - top, 0, 1, rows)
        return
    end

    -- Slanted top edge: column by column, each column's pieces stacked down
    -- from the edge's height there (so the tufts follow the slant). A column
    -- lower than the tallest one uses the pieces nearest the top.
    for u = 0, ts - 1 do
        local f = (u + 0.5) / ts
        local topU = math.floor(k[3] + (k[4] - k[3]) * f + 0.5)
        if topU > bottom then
            local rowsU = math.ceil((topU - bottom) / ts - 1e-6)
            for row = 0, rowsU - 1 do
                local quad = quads[rows - rowsU + row]
                sprites.addColumn(batch, sprites.spritesQuads[quad], u, 0,
                    screenX + u, screenY - bandBottomOf(row, topU, rowsU), 1)
            end
            sprites.addColumn(batch, gradient, u, 0, screenX + u, screenY + ts - topU, rowsU)
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
