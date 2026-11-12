-- mountain.lua
--
-- Adds the ART for an elevated tile's south-facing cliff face to the tile
-- sprite batch. (Lighting/shadow data for cliffs lives in terrain.lua; this
-- file is only about which sprites to draw.)
--
-- A tile with height H (px) has a face H px tall directly below its top,
-- drawn as a column of 32 px face sprites from the bottom row up.
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
--     +1  if the tile to the RIGHT is tall enough to cover this row
--         (so no right-hand edge/corner should be drawn)
--     +2  if the tile to the LEFT covers this row (no left edge)
--
-- Quad 45 is a dark gradient stretched over the whole face for depth.

mountain = {}

local FACE_SINGLE, FACE_BOTTOM, FACE_MIDDLE, FACE_TOP = 23, 27, 31, 35
local FACE_GRADIENT = 45

-- xC, yC          tile coordinates (1-based)
-- z               tile's z from mapArray (negative = raised)
-- screenX, screenY   where the tile would be drawn at ground level
function mountain:add(xC, yC, z, screenX, screenY)
    local ts = sprites.size
    local height = -z
    local rows = height / ts                       -- face height in tiles
    local leftH  = terrain:heightAtTile(xC - 1, yC)
    local rightH = terrain:heightAtTile(xC + 1, yC)

    -- row 0 is the bottom of the face (at the tile's own ground position),
    -- row rows-1 is the top (just under the tile's raised top surface).
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

        local rowBottomHeight = row * ts           -- height of this row's lower edge
        if rightH > rowBottomHeight then quad = quad + 1 end
        if leftH  > rowBottomHeight then quad = quad + 2 end

        sprites.tileBatch:add(sprites.spritesQuads[quad], screenX, screenY - row * ts)
    end

    -- Shading gradient over the full face, stretched to its height.
    sprites.tileBatch:add(sprites.spritesQuads[FACE_GRADIENT],
        screenX, screenY - (rows - 1) * ts, 0, 1, rows)
end

-- Screen rectangle an elevated tile covers (its top + face). Anything drawn
-- on the object canvas earlier (i.e. further back) inside this area is
-- hidden behind the cliff. Returns x, y, w, h.
function mountain:footprint(z, screenX, screenY)
    local ts = sprites.size
    return screenX, screenY + z, ts, ts - z
end
