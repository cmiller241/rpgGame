-- terrain.lua
--
-- Owns the elevation data and the two GPU textures the lighting shaders use
-- to understand the 3D shape of the world.
--
-- COORDINATE SYSTEM
-- -----------------
-- The game is drawn in an oblique "3/4" view: something standing at world
-- position (x, y) with height h appears on screen at
--
--     screenX = x - cameraX
--     screenY = y - h - cameraY        (higher things are drawn further up)
--
-- Heights here are pixels, POSITIVE UPWARD: 64 is a cliff two tiles tall,
-- -32 is a pit one tile deep. (mapArray stores the opposite sign as z, e.g.
-- z = -64 for that cliff, z = 32 for that pit.)
--
-- A tile at tile row r with height H occupies, on screen (y0 = the tile's
-- top edge at ground level):
--   * its flat TOP      from y0 - H to y0 - H + 32
--   * its south FACE    from y0 - H + 32 down to y0 + 32 - B   (a vertical wall)
-- where B = terrain:faceBottom(): the wall runs down to whichever is lower,
-- ground level or the tile in front (south) of it. So:
--   * a raised tile's wall drops to the ground, or further into a pit in front
--   * a ground tile in front of nothing lower has no wall
--   * a ground tile BEHIND a pit has a wall down to the pit floor: that's the
--     pit's back wall, the only wall of a pit the camera can see
-- A pit's floor is drawn lower on screen, so the ground in front of it hides
-- part of the floor (all of it, if the pit is a tile or more deep).
--
-- THE TWO TEXTURES
-- ----------------
-- 1. heightMap  (world space, 1 texel per tile)
--    The height of every tile. Shaders ray-march through this to answer
--    "is anything between this point and the light?" Because it covers the
--    whole map, occluders that are off-screen or hidden behind other terrain
--    still cast shadows correctly.
--
-- 2. surface map  (screen space, canvas.surface, redrawn every frame)
--    For every screen pixel: is it a cliff FACE or a flat TOP, and how high
--    is that exact point? With that, a shader can turn any screen pixel back
--    into a 3D world point:
--
--        world = (screenX + cameraX, screenY + cameraY + h, h)
--
--    Channels:  R = 1 on cliff faces, 0 on tops/ground
--               G = water depth / heightRange on water surfaces (see water.lua)
--               B = height / terrain.heightRange, NEGATIVE in pits (the
--                   canvas is 16-bit float, so negatives are fine). Faces
--                   have a vertical gradient: top height at the top edge,
--                   faceBottom at the base.
--               A = 1
--
--    It is built from one Mesh containing every tile that isn't plain flat
--    ground, drawn in a single call with the camera offset, so it costs about
--    the same as drawing one sprite.

local terrain = {}
package.loaded[...] = terrain  -- register now, so modules that require each other share this table

local canvas = require("src.canvas")
local shader = require("src.shader")
local window = require("src.window")

terrain.tileSize    = 32
terrain.heightRange = 1024   -- surface map stores height / heightRange (keeps values in -1..1)

-- The heightmap texture stores unsigned 16-bit numbers, so heights are
-- stored with this added (and subtracted again in terrainCommon.glsl).
terrain.heightBias  = 32768

-- Shadow ray-march settings. These MUST match SUN_STEP/SUN_STEPS in
-- shaders/terrainCommon.glsl so CPU and GPU agree on what's in shadow.
terrain.sunStep  = 3
terrain.sunSteps = 160

-- Reads mapArray and builds everything. To change one tile's height at
-- runtime use terrain:setTileHeight (changing tile TYPES, e.g. plowing,
-- needs nothing).
function terrain:build(map)
    self.map = map
    self.rows = #map
    self.cols = 0
    for r = 1, self.rows do
        self.cols = math.max(self.cols, #map[r])
    end

    -- Heights in pixels (positive up), [row][col]. Missing cells (ragged rows) = 0.
    -- Floating blocks: map cell [3] is the height of a block's underside
    -- (0 or missing = no block). See FLOATING BLOCKS below.
    self.version = (self.version or 0) + 1   -- bumped whenever heights change
    self.heights = {}
    self.blocks = {}
    for r = 1, self.rows do
        local row = {}
        for c = 1, self.cols do
            local cell = map[r][c]
            row[c] = cell and -cell[2] or 0
            if cell and cell[3] and cell[3] ~= 0 then
                self.blocks[r] = self.blocks[r] or {}
                self.blocks[r][c] = cell[3]
            end
        end
        self.heights[r] = row
    end
    self:updateExtents()

    self:buildHeightMap()
    self:buildCorners()
    self:buildSurfaceMesh()
end

-- SLOPES
-- ------
-- Neighbouring tiles whose heights differ by less than slopeLimit are
-- "joined": instead of a little cliff between them, the ground slants
-- smoothly from one to the other. Bigger differences stay cliffs, so a map
-- built from whole-tile heights (multiples of 32) has no slopes at all and
-- draws exactly as it always did.
--
-- Each tile still has ONE height in the map (heights[row][col]; water and
-- the Q tool work with that). What's drawn and walked on is a surface
-- through five points per tile, k = {nw, ne, sw, se, centre}:
--   * CORNERS: a corner is shared by up to four tiles; they're grouped by
--     joined edges (north-south and east-west neighbours, not diagonals),
--     and every tile in a group uses the group's average height there.
--     Tiles on either side of a joined edge are always in the same group,
--     so their shared corners match and the ground has no seams.
--   * CENTRE: the tile's own height, so a lone raised tile still peaks at
--     the height it was given (averaging alone would flatten it).
-- Inside a tile the surface is four bilinear quarters through the corners,
-- the edge midpoints (halfway between two corners) and the centre; see
-- terrain.edgeHeights. Edges depend only on their two corners, which is
-- what keeps neighbouring tiles seamless.
--
-- The surface also feeds:
--   * cornerMap, a texture with 3x3 texels per tile (corners, edge
--     midpoints, centre) and linear filtering, so one shader lookup returns
--     the exact sloped height at any world point without bleeding into
--     neighbouring tiles. It also holds the slope there, for sunlight on
--     slopes, and the tile's floating block. See terrainAt() in
--     shaders/terrainCommon.glsl.
--   * the surface mesh (sloped tops, walls under a sloped edge)
--   * the tile sprites, which are warped onto sloped tops (sprites.lua)
terrain.slopeLimit = 32

function terrain:joined(a, b)
    return math.abs(a - b) < self.slopeLimit
end

-- Is tile (col, row) joined to the tile in front of it (south)? Then the
-- ground slants (or stays level) into that tile and there's no wall between.
function terrain:joinedSouth(col, row)
    local below = self.heights[row + 1]
    return below ~= nil and below[col] ~= nil and self:joined(self.heights[row][col], below[col])
end

-- Height of grid point (gx, gy) as seen from tile (col, row), one of the
-- four tiles around it: the average height of the tiles in its group there.
-- Grid point (gx, gy) is the corner shared by tiles (gx-1, gy-1),
-- (gx, gy-1), (gx-1, gy) and (gx, gy).
local NEIGHBOUR_PAIRS = { {1, 2}, {3, 4}, {1, 3}, {2, 4} }   -- NW-NE, SW-SE, NW-SW, NE-SE
function terrain:cornerHeight(col, row, gx, gy)
    local cs = { gx - 1, gx, gx - 1, gx }
    local rs = { gy - 1, gy - 1, gy, gy }
    local hs, parent = {}, { 1, 2, 3, 4 }
    for i = 1, 4 do
        local r = self.heights[rs[i]]
        hs[i] = r and r[cs[i]] or false            -- false = off the map
    end
    local function find(i)
        while parent[i] ~= i do i = parent[i] end
        return i
    end
    for _, p in ipairs(NEIGHBOUR_PAIRS) do
        local a, b = p[1], p[2]
        if hs[a] and hs[b] and self:joined(hs[a], hs[b]) then parent[find(a)] = find(b) end
    end
    local me = (col == gx - 1 and 1 or 2) + (row == gy - 1 and 0 or 2)
    local root, sum, n = find(me), 0, 0
    for i = 1, 4 do
        if hs[i] and find(i) == root then sum, n = sum + hs[i], n + 1 end
    end
    return sum / n
end

-- Heights along a tile's north edge, middle line and south edge at fx
-- (0 = west side, 1 = east side), for its five points k. The surface
-- between them is linear top-to-middle and middle-to-bottom.
function terrain.edgeHeights(k, fx)
    local n = k[1] + (k[2] - k[1]) * fx
    local s = k[3] + (k[4] - k[3]) * fx
    local w, e = (k[1] + k[3]) / 2, (k[2] + k[4]) / 2
    local m
    if fx < 0.5 then m = w + (k[5] - w) * fx * 2 else m = k[5] + (e - k[5]) * (fx * 2 - 1) end
    return n, m, s
end

-- Height at (fx, fy) inside a tile with points k (0..1 across, 0..1 down).
function terrain.heightInTile(k, fx, fy)
    if k.flat then return k[1] end
    local n, m, s = terrain.edgeHeights(k, fx)
    if fy < 0.5 then return n + (m - n) * fy * 2 end
    return m + (s - m) * (fy * 2 - 1)
end

-- Works out every tile's five surface points (self.corners[row][col] =
-- {nw, ne, sw, se, centre, flat = all five equal}), then (re)builds
-- cornerMap. Called whenever heights change.
function terrain:buildCorners()
    local corners = {}
    self.corners = corners
    self.hasSlopes = false
    for r = 1, self.rows do
        local row = {}
        for c = 1, self.cols do
            local h = self.heights[r][c]
            local k = { self:cornerHeight(c, r, c, r), self:cornerHeight(c, r, c + 1, r),
                        self:cornerHeight(c, r, c, r + 1), self:cornerHeight(c, r, c + 1, r + 1), h }
            k.flat = k[1] == h and k[2] == h and k[3] == h and k[4] == h
            if not k.flat then self.hasSlopes = true end
            row[c] = k
        end
        corners[r] = row
    end
    self:buildCornerMap()
end

-- Surface points {nw, ne, sw, se, centre, flat=...} of tile (col, row).
-- Off the map: flat ground.
local OFF_MAP_CORNERS = { 0, 0, 0, 0, 0, flat = true }
function terrain:cornersOf(col, row)
    local r = self.corners[row]
    return r and r[col] or OFF_MAP_CORNERS
end

-- Ground height (px) at world point (wx, wy), following slopes. The same
-- height the sprites, surface map and shaders use.
function terrain:surfaceHeight(wx, wy)
    local ts = self.tileSize
    local col, row = math.floor(wx / ts) + 1, math.floor(wy / ts) + 1
    return terrain.heightInTile(self:cornersOf(col, row), wx / ts - (col - 1), wy / ts - (row - 1))
end

-- Highest ground (px) on tile (col, row) within the world rectangle
-- x0..x1, y0..y1 (clipped to the tile). Each quarter of a tile is bilinear,
-- so the highest point is at a corner of the rectangle or where it crosses
-- the tile's middle lines.
function terrain:groundMaxIn(col, row, x0, y0, x1, y1)
    local k = self:cornersOf(col, row)
    if k.flat then return k[1] end
    local ts = self.tileSize
    local tx0, ty0 = (col - 1) * ts, (row - 1) * ts
    local function clamp01(v) return math.max(0, math.min(1, v)) end
    local fx0, fx1 = clamp01((x0 - tx0) / ts), clamp01((x1 - tx0) / ts)
    local fy0, fy1 = clamp01((y0 - ty0) / ts), clamp01((y1 - ty0) / ts)
    local xs, ys = { fx0, fx1 }, { fy0, fy1 }
    if fx0 < 0.5 and fx1 > 0.5 then xs[3] = 0.5 end
    if fy0 < 0.5 and fy1 > 0.5 then ys[3] = 0.5 end
    local best = -math.huge
    for _, fx in ipairs(xs) do
        for _, fy in ipairs(ys) do
            best = math.max(best, terrain.heightInTile(k, fx, fy))
        end
    end
    return best
end

-- CORNER MAP: 3x3 texels per tile, rgba16f, linear filtering.
--   R  ground height (px) at that point (corners, edge midpoints, centre)
--   G  slope there: rise per px going east  (smoothed, see slopeAt)
--   B  slope there: rise per px going south
--   A  the tile's floating block underside (px), or NO_BLOCK_TEXEL
-- A shader samples tile (c, r) at texel (3c + 0.5 + 2 fx, 3r + 0.5 + 2 fy)
-- (0-based c, r; fx, fy = 0..1 across the tile), which blends only that
-- tile's texels: exactly the sloped surface, no bleeding.
terrain.NO_BLOCK_TEXEL = -30000

function terrain:buildCornerMap()
    local data = self.cornerData
    if not data or data:getWidth() ~= self.cols * 3 or data:getHeight() ~= self.rows * 3 then
        local format = love.graphics.getImageFormats()["rgba16f"] and "rgba16f" or "rgba32f"
        data = love.image.newImageData(self.cols * 3, self.rows * 3, format)
        self.cornerData = data
        self.cornerMap = nil
    end
    for r = 1, self.rows do
        for c = 1, self.cols do
            self:writeCornerTexels(c, r)
        end
    end
    if self.cornerMap then
        self.cornerMap:replacePixels(data)
    else
        self.cornerMap = love.graphics.newImage(data)
        self.cornerMap:setFilter("linear", "linear")
        self.cornerMap:setWrap("clamp", "clamp")
    end
end

-- Does tile (col, row) or any neighbour slope? Only those need their slope
-- worked out for lighting; everything else is flat.
function terrain:nearSlope(col, row)
    for r = row - 1, row + 1 do
        for c = col - 1, col + 1 do
            if not self:cornersOf(c, r).flat then return true end
        end
    end
    return false
end

-- Smoothed slope (rise per px east, south) of tile (col, row)'s surface at
-- (fx, fy): a central difference SLOPE_SAMPLE px either side. A sample that
-- lands across a cliff edge is ignored (the other side's one-sided
-- difference is used), so cliffs don't tilt the ground next to them.
local SLOPE_SAMPLE = 8
function terrain:slopeAt(col, row, fx, fy)
    local ts = self.tileSize
    local k = self.corners[row][col]
    local wx, wy = (col - 1 + fx) * ts, (row - 1 + fy) * ts
    local h0 = terrain.heightInTile(k, fx, fy)
    local function sample(dx, dy)
        local sx, sy = fx + dx / ts, fy + dy / ts
        if sx >= 0 and sx <= 1 and sy >= 0 and sy <= 1 then return terrain.heightInTile(k, sx, sy) end
        return self:surfaceHeight(wx + dx, wy + dy)
    end
    local function diff(dx, dy)
        local hp, hm = sample(dx, dy), sample(-dx, -dy)
        local okP = math.abs(hp - h0) < SLOPE_SAMPLE * 1.5
        local okM = math.abs(h0 - hm) < SLOPE_SAMPLE * 1.5
        if okP and okM then return (hp - hm) / (2 * SLOPE_SAMPLE) end
        if okP then return (hp - h0) / SLOPE_SAMPLE end
        if okM then return (h0 - hm) / SLOPE_SAMPLE end
        return 0
    end
    return diff(SLOPE_SAMPLE, 0), diff(0, SLOPE_SAMPLE)
end

function terrain:writeCornerTexels(c, r)
    local k = self.corners[r][c]
    local b = self:blockAt(c, r)
    local blockValue = b or self.NO_BLOCK_TEXEL
    local sloped = self.hasSlopes and self:nearSlope(c, r)
    for j = 0, 2 do
        for i = 0, 2 do
            local fx, fy = i / 2, j / 2
            local sx, sy = 0, 0
            if sloped then sx, sy = self:slopeAt(c, r, fx, fy) end
            self.cornerData:setPixel((c - 1) * 3 + i, (r - 1) * 3 + j,
                terrain.heightInTile(k, fx, fy), sx, sy, blockValue)
        end
    end
end

-- Changes several tiles' heights at once ({ {col, row, h}, ... }) and
-- rebuilds once, instead of once per tile.
function terrain:setTileHeights(list)
    for _, t in ipairs(list) do
        local cell = self.map[t[2]] and self.map[t[2]][t[1]]
        if cell then
            cell[2] = -t[3]
            self.heights[t[2]][t[1]] = t[3]
            self:writeHeightTexel(t[1], t[2])
        end
    end
    self.version = self.version + 1
    self:updateExtents()
    self.heightMap:replacePixels(self.heightData)
    self:buildCorners()
    self:buildSurfaceMesh()
end

-- FLOATING BLOCKS
-- A tile can have one floating block: a 32 px cube whose underside is at
-- `bottom` px (so its top is at bottom + 32), with open space between it
-- and the ground. Blocks are part of the terrain for drawing and lighting
-- (their top and front faces are in the surface map, they cast shadows via
-- the heightmap's B channel), and the player can stand on them, walk under
-- them, and bump into them (player.lua).
terrain.blockSize = 32

-- Underside height (px) of the block on tile (col, row), or nil.
function terrain:blockAt(col, row)
    local r = self.blocks[row]
    return r and r[col]
end

-- Adds a block over tile (col, row) with its underside at `bottom` px, or
-- removes it (bottom = nil). Bottoms are rounded to 8 px (heightmap storage).
function terrain:setBlock(col, row, bottom)
    local cell = self.map[row] and self.map[row][col]
    if not cell then return end
    if bottom then bottom = math.floor(bottom / 8 + 0.5) * 8 end
    cell[3] = bottom or 0
    self.blocks[row] = self.blocks[row] or {}
    self.blocks[row][col] = bottom
    self.version = self.version + 1
    self:updateExtents()
    self:writeHeightTexel(col, row)
    self.heightMap:replacePixels(self.heightData)
    self:writeCornerTexels(col, row)               -- the block lives in the corner map's A channel
    self.cornerMap:replacePixels(self.cornerData)
    self:buildSurfaceMesh()
end

-- Height of the highest surface on tile (col, row) that something at height
-- `h` could be standing on: the block's top if it's at or below h, otherwise
-- the ground.
-- With a rectangle (x0, y0, x1, y1, world px), the ground is the highest
-- point of the (possibly sloped) surface inside it; without, the tile's height.
function terrain:supportAt(col, row, h, x0, y0, x1, y1)
    local ground = x0 and self:groundMaxIn(col, row, x0, y0, x1, y1) or self:heightAtTile(col, row)
    local b = self:blockAt(col, row)
    if b and b + self.blockSize <= h + 0.5 and b + self.blockSize > ground then
        return b + self.blockSize
    end
    return ground
end

-- Recomputes maxHeight and minHeight. maxHeight is the highest thing that
-- can block light: the tallest tile or the top of the highest block (>= 0).
-- minHeight is the deepest pit (<= 0). Shaders use these to stop shadow
-- rays early and to size their work.
function terrain:updateExtents()
    self.maxHeight, self.minHeight = 0, 0
    for r = 1, self.rows do
        for c = 1, self.cols do
            local h = self.heights[r][c]
            if h > self.maxHeight then self.maxHeight = h end
            if h < self.minHeight then self.minHeight = h end
        end
    end
    for _, row in pairs(self.blocks) do
        for _, b in pairs(row) do
            self.maxHeight = math.max(self.maxHeight, b + self.blockSize)
        end
    end
    assert(self.maxHeight < self.heightRange and -self.minHeight < self.heightRange,
        "terrain taller/deeper than heightRange; raise terrain.heightRange")
end

local function encodeHeight(h)
    local v = h + terrain.heightBias
    return math.floor(v / 256) / 255, (v % 256) / 255
end

-- Changes the height (px, positive = up, negative = pit) of one tile and
-- updates everything that depends on it: the map cell's z, the heightmap
-- texel, the tallest/deepest heights, and the surface mesh. Cheap enough to
-- call on a key press.
function terrain:setTileHeight(col, row, h)
    local cell = self.map[row] and self.map[row][col]
    if not cell then return end

    cell[2] = -h
    self.heights[row][col] = h
    self.version = self.version + 1   -- lets water.lua notice the land changed
    self:updateExtents()   -- ~10,000 comparisons: instant, and never stale

    self:writeHeightTexel(col, row)
    self.heightMap:replacePixels(self.heightData)
    self:buildCorners()    -- neighbours' corners can change too; cheap enough for a key press
    self:buildSurfaceMesh()
end

-- Writes tile (col, row) into the heightmap data:
--   R, G  ground height + heightBias (high byte, low byte)
--   B     floating block: 0 = none, else (underside / 8 + 128) / 255,
--         so undersides from -1016 to +1008 px in 8 px steps
-- Decoded by terrainAt() in terrainCommon.glsl.
function terrain:writeHeightTexel(col, row)
    local hi, lo = encodeHeight(self.heights[row][col])
    local b = self:blockAt(col, row)
    local blockByte = b and (b / 8 + 128) / 255 or 0
    self.heightData:setPixel(col - 1, row - 1, hi, lo, blockByte, 1)
end

-- Height (px) at the bottom of tile (col, row)'s south wall: the lower of
-- ground level and the tile in front of it. If this isn't below the tile's
-- own height, the tile has no visible wall.
function terrain:faceBottom(col, row)
    return math.min(0, self:heightAtTile(col, row + 1))
end

-- Height (px) of tile (col, row), 1-based. Anything off the map is flat ground.
function terrain:heightAtTile(col, row)
    local r = self.heights[row]
    return r and r[col] or 0
end

-- Height (px) of the ground at a world-space point (follows slopes).
function terrain:heightAtWorld(wx, wy)
    return self:surfaceHeight(wx, wy)
end

-- Heights (+ heightBias) are packed into two 8-bit channels (R = high byte,
-- G = low byte), so they're exact for any whole-pixel height. Decoded in
-- terrainCommon.glsl.
function terrain:buildHeightMap()
    self.heightData = love.image.newImageData(self.cols, self.rows, "rgba8")  -- kept for single-texel updates
    for r = 1, self.rows do
        for c = 1, self.cols do
            self:writeHeightTexel(c, r)
        end
    end
    local data = self.heightData
    self.heightMap = love.graphics.newImage(data)
    self.heightMap:setFilter("nearest", "nearest")
end

-- Returns a function quad(x0, y0, x1, y1, face, hTop, hBottom, waterDepth)
-- that appends one surface-map rectangle (two triangles) to `verts`.
-- Vertex colour = the surface-map channels: R face, G water depth, B height.
function terrain:quadWriter(verts)
    local range = self.heightRange
    return function(x0, y0, x1, y1, face, hTop, hBottom, waterDepth)
        local w = (waterDepth or 0) / range
        local tl = {x0, y0, face, w, hTop / range, 1}
        local tr = {x1, y0, face, w, hTop / range, 1}
        local bl = {x0, y1, face, w, hBottom / range, 1}
        local br = {x1, y1, face, w, hBottom / range, 1}
        verts[#verts + 1] = tl; verts[#verts + 1] = tr; verts[#verts + 1] = bl
        verts[#verts + 1] = tr; verts[#verts + 1] = br; verts[#verts + 1] = bl
    end
end

-- Appends one surface-map shape with vertical left/right edges at x0 and x1:
-- top edge from (x0, yT0) to (x1, yT1), bottom edge from (x0, yB0) to
-- (x1, yB1), with heights hT0, hT1, hB0, hB1 at those four points. Used for
-- sloped tops and walls under a sloped edge.
function terrain:trapezoid(verts, x0, x1, yT0, yT1, yB0, yB1, face, hT0, hT1, hB0, hB1)
    local range = self.heightRange
    local tl = {x0, yT0, face, 0, hT0 / range, 1}
    local tr = {x1, yT1, face, 0, hT1 / range, 1}
    local bl = {x0, yB0, face, 0, hB0 / range, 1}
    local br = {x1, yB1, face, 0, hB1 / range, 1}
    verts[#verts + 1] = tl; verts[#verts + 1] = tr; verts[#verts + 1] = bl
    verts[#verts + 1] = tr; verts[#verts + 1] = br; verts[#verts + 1] = bl
end

-- A sloped surface is bilinear, which two triangles can't match exactly, so
-- sloped tops and walls are cut into this many vertical strips.
local SLOPE_STRIPS = 8   -- must be even: strips meet the middle line at half the tile

-- Emits tile (c, r)'s surface-map quads: its south wall (if any), then its
-- top, then its floating block (if any, and `withBlock` isn't false).
-- Plain ground (height 0) gets a top only if `groundTop` is true; otherwise
-- the cleared canvas already says "ground". `verts` is the vertex list
-- `quad` appends to (needed for sloped shapes).
--
-- The top follows the tile's corner heights (flat unless it's on a slope).
-- The wall runs from the top's south edge down to faceBottom, unless the
-- tile in front is joined to this one by a slope (then there's no wall).
function terrain:emitTile(c, r, quad, groundTop, withBlock, verts)
    local ts = self.tileSize
    local k = self:cornersOf(c, r)
    local B = self:faceBottom(c, r)
    local x0, y0 = (c - 1) * ts, (r - 1) * ts
    local wall = not self:joinedSouth(c, r)

    if k.flat then
        local H = k[1]
        if wall and B < H then
            quad(x0, y0 + ts - H, x0 + ts, y0 + ts - B, 1, H, B)   -- wall: H at top, B at base
        end
        if H ~= 0 or groundTop then
            quad(x0, y0 - H, x0 + ts, y0 - H + ts, 0, H, H)        -- top at height H
        end
    else
        local half = ts / 2
        for i = 0, SLOPE_STRIPS - 1 do
            local f0, f1 = i / SLOPE_STRIPS, (i + 1) / SLOPE_STRIPS
            local xa, xb = x0 + ts * f0, x0 + ts * f1
            -- North edge, middle line and south edge heights at both sides of the strip.
            local n0, m0, s0 = terrain.edgeHeights(k, f0)
            local n1, m1, s1 = terrain.edgeHeights(k, f1)
            if wall and (s0 > B or s1 > B) then
                local w0, w1 = math.max(s0, B), math.max(s1, B)
                self:trapezoid(verts, xa, xb, y0 + ts - w0, y0 + ts - w1, y0 + ts - B, y0 + ts - B,
                    1, w0, w1, B, B)
            end
            -- The top in two halves: north edge to middle line, middle line to south edge.
            self:trapezoid(verts, xa, xb, y0 - n0, y0 - n1, y0 + half - m0, y0 + half - m1,
                0, n0, n1, m0, m1)
            self:trapezoid(verts, xa, xb, y0 + half - m0, y0 + half - m1, y0 + ts - s0, y0 + ts - s1,
                0, m0, m1, s0, s1)
        end
    end
    if withBlock ~= false then self:emitBlock(c, r, quad) end
end

-- Emits tile (c, r)'s floating block, if it has one: its front face (a wall
-- from its top down to its underside, on the tile's south edge), then its top.
function terrain:emitBlock(c, r, quad)
    local b = self:blockAt(c, r)
    if not b then return end
    local ts, T = self.tileSize, b + self.blockSize
    local x0, y0 = (c - 1) * ts, (r - 1) * ts
    quad(x0, y0 + ts - T, x0 + ts, y0 + ts - b, 1, T, b)   -- front face
    quad(x0, y0 - T, x0 + ts, y0 - T + ts, 0, T, T)        -- top
end

-- One quad for each tile's top and one for its south face, in back-to-front
-- (row-major) order so nearer terrain overwrites farther terrain, exactly
-- like the tile sprites do.
--
-- Plain flat ground needs no quad (the canvas is cleared to "ground"),
-- EXCEPT ground just in front of a pit: a pit floor is drawn lower than its
-- own row, so the ground in front has to be drawn over it.
function terrain:buildSurfaceMesh()
    local ts = self.tileSize
    local verts = {}
    local quad = self:quadWriter(verts)

    -- How many rows a pit floor can sink into the rows in front of it.
    local pitReach = math.ceil(-self.minHeight / ts)

    for r = 1, self.rows do
        for c = 1, self.cols do
            -- Ground needs a top only if a pit behind might show through.
            local groundTop = false
            for k = 1, pitReach do
                if self:heightAtTile(c, r - k) < 0 then groundTop = true break end
            end
            self:emitTile(c, r, quad, groundTop, true, verts)
        end
    end

    self.surfaceMesh = self:newSurfaceMesh(verts)   -- nil for a completely flat map
    self.focusMeshes = {}                            -- pit layers are stale now
    self:buildHiders(pitReach)
end

-- Which tiles can hide sprites drawn earlier (further back)? Raised tiles
-- always can. Ground (or a shallower pit) can only hide something standing
-- on LOWER ground behind it, i.e. in a pit within `pitReach` rows to the
-- north. Columns 2 either side are checked too, since sprites are wider than
-- a tile. Without this, every ground tile on screen would erase its
-- footprint each frame whenever any pit exists, which is slow.
function terrain:buildHiders(pitReach)
    self.hiders = {}
    for r = 1, self.rows do
        local row = {}
        for c = 1, self.cols do
            local H = self.heights[r][c]
            local hides = H > 0
            for k = 1, pitReach do
                if hides then break end
                for dc = -2, 2 do
                    if self:heightAtTile(c + dc, r - k) < H then hides = true break end
                end
            end
            row[c] = hides
        end
        self.hiders[r] = row
    end
end

-- Does tile (col, row) hide sprites behind it? (See buildHiders.)
function terrain:hidesBehind(col, row)
    local r = self.hiders[row]
    return r ~= nil and r[col] == true
end

-- Float vertex colours so heights aren't rounded to 8 bits before they
-- reach the (16-bit float) surface canvas.
function terrain:newSurfaceMesh(verts)
    if #verts == 0 then return nil end
    return love.graphics.newMesh(
        {{"VertexPosition", "float", 2}, {"VertexColor", "float", 4}},
        verts, "triangles", "static")
end

-- Renders the visible part of the surface map into canvas.surface.
function terrain:drawSurfaceMap(cameraX, cameraY)
    love.graphics.setCanvas(canvas.surface)
    love.graphics.clear(0, 0, 0, 1)            -- flat ground, height 0
    if self.surfaceMesh then
        love.graphics.setBlendMode("replace")
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.surfaceMesh, -cameraX, -cameraY)
        love.graphics.setBlendMode("alpha")
    end
end

-- PIT FOCUS LAYER
-- While the player is in a pit, only the tiles at or below his level are
-- also rendered on their own (see lighting.lua). This is the surface-map
-- mesh for that layer: tops and walls of tiles with height <= level, and
-- nothing else. Built once per level and cached until the terrain changes.
function terrain:focusMesh(level)
    if self.focusMeshes[level] == nil then
        local verts = {}
        local quad = self:quadWriter(verts)
        for r = 1, self.rows do
            for c = 1, self.cols do
                if self.heights[r][c] <= level then
                    self:emitTile(c, r, quad, true, false, verts)   -- blocks float above: not part of the pit
                end
            end
        end
        self.focusMeshes[level] = self:newSurfaceMesh(verts) or false
    end
    return self.focusMeshes[level] or nil
end

-- Renders the pit layer's terrain shape into canvas.focusSurface. Alpha is 0
-- wherever the layer has nothing, so the shader can tell.
function terrain:drawFocusSurface(level, cameraX, cameraY)
    love.graphics.setCanvas(canvas.focusSurface)
    love.graphics.clear(0, 0, 0, 0)
    local mesh = self:focusMesh(level)
    if mesh then
        love.graphics.setBlendMode("replace")
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(mesh, -cameraX, -cameraY)
        love.graphics.setBlendMode("alpha")
    end
end

-- Is tile height h part of the pit layer for `level`?
function terrain:inFocusLayer(h, level)
    return h <= level
end

-- Sends the uniforms declared in terrainCommon.glsl to a shader. Uniforms the
-- shader compiler optimised away are skipped (LÖVE errors on those).
function terrain:sendUniforms(s, cameraX, cameraY)
    shader.sendIfPresent(s, "surfaceMap", canvas.surface)
    shader.sendIfPresent(s, "heightMap", self.heightMap)
    -- The corner map gives the shaders sloped ground (see SLOPES). The web
    -- build shares these shaders but doesn't send it yet, so they only use
    -- it when told to.
    shader.sendIfPresent(s, "cornerMap", self.cornerMap)
    shader.sendIfPresent(s, "useCornerMap", true)
    shader.sendIfPresent(s, "mapTiles", {self.cols, self.rows})
    shader.sendIfPresent(s, "tileSize", self.tileSize)
    shader.sendIfPresent(s, "heightRange", self.heightRange)
    shader.sendIfPresent(s, "maxTerrainHeight", self.maxHeight)
    shader.sendIfPresent(s, "heightBias", self.heightBias)
    shader.sendIfPresent(s, "camera", {cameraX, cameraY})
    shader.sendIfPresent(s, "screenSize", {window.width, window.height})
end

-- CPU version of terrainShadow() in terrainCommon.glsl: how much of the sun
-- (0..1) terrain and floating blocks block for a world point. Used to darken
-- sprites (player, trees, crops) standing in a cliff's or block's shadow,
-- since the GPU pass only shades terrain pixels. Sprites are small, so a
-- single ray with the far-end soft fade is enough (the shader also fans rays
-- sideways).
function terrain:sunShadowAmount(wx, wy, h, sunState)
    if not sunState.isUp or h >= self.maxHeight then return 0 end
    local maxDist = math.min((self.maxHeight - h) / sunState.slope, self.sunStep * self.sunSteps)
    local invSoft = 0.5 / math.max(sunState.softness, 1e-4)
    local ts = self.tileSize
    local lit = 1
    local d = self.sunStep
    while d <= maxDist do
        local rayH = h + d * sunState.slope
        local qx, qy = wx + sunState.dirX * d, wy + sunState.dirY * d
        local col, row = math.floor(qx / ts) + 1, math.floor(qy / ts) + 1
        local tileH = self:surfaceHeight(qx, qy)
        local v = math.max(0, math.min(1, 0.5 + (rayH - tileH) / d * invSoft))
        local b = self:blockAt(col, row)
        if b and rayH > b and rayH < b + self.blockSize then v = 0 end   -- through a block
        if v < lit then
            lit = v
            if lit <= 0 then return 1 end
        end
        d = d + self.sunStep
    end
    return 1 - lit
end

return terrain
