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
-- Heights here are POSITIVE pixels upward. (mapArray stores them as negative
-- z, e.g. z = -64 means a cliff two tiles tall.)
--
-- An elevated tile at tile row r with height H therefore occupies, on screen:
--   * its flat TOP      from y0 - H      to y0 - H + 32
--   * its south FACE    from y0 - H + 32 to y0 + 32   (a vertical wall)
-- where y0 is the tile's top edge at ground level.
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
--               B = height / terrain.heightRange   (faces have a vertical
--                   gradient: H at the top edge, 0 at the base)
--               A = 1
--
--    It is built from one Mesh containing every elevated tile, drawn in a
--    single call with the camera offset, so it costs about the same as
--    drawing one sprite.

local terrain = {}
package.loaded[...] = terrain  -- register now, so modules that require each other share this table

local canvas = require("src.canvas")
local shader = require("src.shader")
local window = require("src.window")

terrain.tileSize    = 32
terrain.heightRange = 1024   -- surface map stores height / heightRange (keeps values in 0..1)

-- Shadow ray-march settings. These MUST match SUN_STEP/SUN_STEPS in
-- shaders/terrainCommon.glsl so CPU and GPU agree on what's in shadow.
terrain.sunStep  = 3
terrain.sunSteps = 160

-- Reads mapArray and builds everything. Call again if tile HEIGHTS change at
-- runtime (changing tile TYPES, e.g. plowing, doesn't need a rebuild).
function terrain:build(map)
    self.map = map
    self.rows = #map
    self.cols = 0
    for r = 1, self.rows do
        self.cols = math.max(self.cols, #map[r])
    end

    -- Positive heights in pixels, [row][col]. Missing cells (ragged rows) = 0.
    self.heights = {}
    self.maxHeight = 0
    for r = 1, self.rows do
        local row = {}
        for c = 1, self.cols do
            local cell = map[r][c]
            local h = cell and -cell[2] or 0
            row[c] = h
            if h > self.maxHeight then self.maxHeight = h end
        end
        self.heights[r] = row
    end
    assert(self.maxHeight < self.heightRange,
        "terrain taller than heightRange; raise terrain.heightRange")

    self:buildHeightMap()
    self:buildSurfaceMesh()
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

-- Heights are packed into two 8-bit channels (R = high byte, G = low byte),
-- so they're exact up to 65535 px. Decoded in terrainCommon.glsl.
function terrain:buildHeightMap()
    local data = love.image.newImageData(self.cols, self.rows, "rgba8")
    for r = 1, self.rows do
        for c = 1, self.cols do
            local h = self.heights[r][c]
            data:setPixel(c - 1, r - 1, math.floor(h / 256) / 255, (h % 256) / 255, 0, 1)
        end
    end
    self.heightMap = love.graphics.newImage(data)
    self.heightMap:setFilter("nearest", "nearest")
end

-- One quad for each tile's top and one for its south face, in back-to-front
-- (row-major) order so nearer cliffs overwrite farther ones, exactly like the
-- tile sprites do.
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

    for r = 1, self.rows do
        for c = 1, self.cols do
            local H = self.heights[r][c]
            if H > 0 then
                local x0, y0 = (c - 1) * ts, (r - 1) * ts
                -- South face: height runs from H at its top edge down to 0.
                quad(x0, y0 + ts - H, x0 + ts, y0 + ts, 1, H, 0)
                -- Flat top at height H.
                quad(x0, y0 - H, x0 + ts, y0 - H + ts, 0, H, H)
            end
        end
    end

    if #verts == 0 then
        self.surfaceMesh = nil -- completely flat map
        return
    end

    -- Float vertex colours so heights aren't rounded to 8 bits before they
    -- reach the (16-bit float) surface canvas.
    self.surfaceMesh = love.graphics.newMesh(
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

-- Sends the uniforms declared in terrainCommon.glsl to a shader. Uniforms the
-- shader compiler optimised away are skipped (LÖVE errors on those).
function terrain:sendUniforms(s, cameraX, cameraY)
    shader.sendIfPresent(s, "surfaceMap", canvas.surface)
    shader.sendIfPresent(s, "heightMap", self.heightMap)
    shader.sendIfPresent(s, "mapTiles", {self.cols, self.rows})
    shader.sendIfPresent(s, "tileSize", self.tileSize)
    shader.sendIfPresent(s, "heightRange", self.heightRange)
    shader.sendIfPresent(s, "maxTerrainHeight", self.maxHeight)
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
