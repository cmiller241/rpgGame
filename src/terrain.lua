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
--               G = unused
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
    self.heights = {}
    for r = 1, self.rows do
        local row = {}
        for c = 1, self.cols do
            local cell = map[r][c]
            row[c] = cell and -cell[2] or 0
        end
        self.heights[r] = row
    end
    self:updateExtents()

    self:buildHeightMap()
    self:buildSurfaceMesh()
end

-- Recomputes maxHeight (tallest tile, >= 0) and minHeight (deepest pit, <= 0).
-- Shaders use these to stop shadow rays early and size their work.
function terrain:updateExtents()
    self.maxHeight, self.minHeight = 0, 0
    for r = 1, self.rows do
        for c = 1, self.cols do
            local h = self.heights[r][c]
            if h > self.maxHeight then self.maxHeight = h end
            if h < self.minHeight then self.minHeight = h end
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
    self:updateExtents()   -- ~10,000 comparisons: instant, and never stale

    local hi, lo = encodeHeight(h)
    self.heightData:setPixel(col - 1, row - 1, hi, lo, 0, 1)
    self.heightMap:replacePixels(self.heightData)
    self:buildSurfaceMesh()
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

-- Height (px) at a world-space point on the ground plane.
function terrain:heightAtWorld(wx, wy)
    local ts = self.tileSize
    return self:heightAtTile(math.floor(wx / ts) + 1, math.floor(wy / ts) + 1)
end

-- Heights (+ heightBias) are packed into two 8-bit channels (R = high byte,
-- G = low byte), so they're exact for any whole-pixel height. Decoded in
-- terrainCommon.glsl.
function terrain:buildHeightMap()
    local data = love.image.newImageData(self.cols, self.rows, "rgba8")
    for r = 1, self.rows do
        for c = 1, self.cols do
            local hi, lo = encodeHeight(self.heights[r][c])
            data:setPixel(c - 1, r - 1, hi, lo, 0, 1)
        end
    end
    self.heightData = data   -- kept so setTileHeight can update single texels
    self.heightMap = love.graphics.newImage(data)
    self.heightMap:setFilter("nearest", "nearest")
end

-- One quad for each tile's top and one for its south face, in back-to-front
-- (row-major) order so nearer terrain overwrites farther terrain, exactly
-- like the tile sprites do.
--
-- Plain flat ground needs no quad (the canvas is cleared to "ground"),
-- EXCEPT ground just in front of a pit: a pit floor is drawn lower than its
-- own row, so the ground in front has to be drawn over it.
function terrain:buildSurfaceMesh()
    local ts, range = self.tileSize, self.heightRange
    local verts = {}

    local function quad(x0, y0, x1, y1, face, hTop, hBottom)
        local tl = {x0, y0, face, 0, hTop / range, 1}
        local tr = {x1, y0, face, 0, hTop / range, 1}
        local bl = {x0, y1, face, 0, hBottom / range, 1}
        local br = {x1, y1, face, 0, hBottom / range, 1}
        for _, v in ipairs({tl, tr, bl, tr, br, bl}) do
            verts[#verts + 1] = v
        end
    end

    -- How many rows a pit floor can sink into the rows in front of it.
    local pitReach = math.ceil(-self.minHeight / ts)

    for r = 1, self.rows do
        for c = 1, self.cols do
            local H = self.heights[r][c]
            local B = self:faceBottom(c, r)
            local x0, y0 = (c - 1) * ts, (r - 1) * ts

            -- South face: height runs from H at its top edge down to B.
            if B < H then
                quad(x0, y0 + ts - H, x0 + ts, y0 + ts - B, 1, H, B)
            end

            -- Flat top at height H (ground only if a pit behind might show through).
            local needTop = H ~= 0
            for k = 1, pitReach do
                if needTop then break end
                if self:heightAtTile(c, r - k) < 0 then needTop = true end
            end
            if needTop then
                quad(x0, y0 - H, x0 + ts, y0 - H + ts, 0, H, H)
            end
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
        local ts, range = self.tileSize, self.heightRange
        local verts = {}
        local function quad(x0, y0, x1, y1, face, hTop, hBottom)
            local tl = {x0, y0, face, 0, hTop / range, 1}
            local tr = {x1, y0, face, 0, hTop / range, 1}
            local bl = {x0, y1, face, 0, hBottom / range, 1}
            local br = {x1, y1, face, 0, hBottom / range, 1}
            for _, v in ipairs({tl, tr, bl, tr, br, bl}) do verts[#verts + 1] = v end
        end
        for r = 1, self.rows do
            for c = 1, self.cols do
                local H = self.heights[r][c]
                if H <= level then
                    local B = self:faceBottom(c, r)
                    local x0, y0 = (c - 1) * ts, (r - 1) * ts
                    if B < H then quad(x0, y0 + ts - H, x0 + ts, y0 + ts - B, 1, H, B) end
                    quad(x0, y0 - H, x0 + ts, y0 - H + ts, 0, H, H)
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
    shader.sendIfPresent(s, "mapTiles", {self.cols, self.rows})
    shader.sendIfPresent(s, "tileSize", self.tileSize)
    shader.sendIfPresent(s, "heightRange", self.heightRange)
    shader.sendIfPresent(s, "maxTerrainHeight", self.maxHeight)
    shader.sendIfPresent(s, "heightBias", self.heightBias)
    shader.sendIfPresent(s, "camera", {cameraX, cameraY})
    shader.sendIfPresent(s, "screenSize", {window.width, window.height})
end

-- CPU version of terrainShadow() in terrainCommon.glsl: how much of the sun
-- (0..1) terrain blocks for a world point. Used to darken sprites (player,
-- trees, crops) standing in a cliff's shadow, since the GPU pass only shades
-- terrain pixels. Sprites are small, so a single ray with the far-end soft
-- fade is enough (the shader also fans rays sideways).
function terrain:sunShadowAmount(wx, wy, h, sunState)
    if not sunState.isUp or h >= self.maxHeight then return 0 end
    local maxDist = math.min((self.maxHeight - h) / sunState.slope, self.sunStep * self.sunSteps)
    local invSoft = 0.5 / math.max(sunState.softness, 1e-4)
    local lit = 1
    local d = self.sunStep
    while d <= maxDist do
        local rayH = h + d * sunState.slope
        local tileH = self:heightAtWorld(wx + sunState.dirX * d, wy + sunState.dirY * d)
        local v = math.max(0, math.min(1, 0.5 + (rayH - tileH) / d * invSoft))
        if v < lit then
            lit = v
            if lit <= 0 then return 1 end
        end
        d = d + self.sunStep
    end
    return 1 - lit
end

return terrain
