-- water.lua
--
-- Water lying on the terrain: how much is on each tile, how it flows, and
-- getting its surface into the surface map so the lighting pass can draw it.
--
-- STATE
-- Each tile can hold a water DEPTH in pixels. Its water SURFACE is then
-- (ground height + depth). Only wet tiles are stored.
--
-- FLOW (water:update, once per fixed tick)
-- Water moves from a tile to any of its 4 neighbours whose water surface is
-- lower, a fraction (flowRate) of the difference per tick. That single rule
-- gives:
--   * spreading out over level ground,
--   * pouring down into pits and off ledges,
--   * filling a pit, then overflowing its rim once the surface is higher.
-- The total amount of water never changes. Two tweaks:
--   * Surface tension: onto DRY level ground (or up over a dry rim) water
--     only moves if the surfaces differ by more than minSpread px, so one
--     cast makes a puddle instead of thinning out across the whole map.
--     Downhill, or into water that's already there, it always moves, so
--     pools level out completely.
--   * The simulation sleeps once nothing is moving, and wakes when water is
--     added or the land changes (terrain.version).
--   * Water slowly evaporates (evaporationRate), even while asleep.
--
-- DRAWING
-- Water has no sprites. Its surface is written into canvas.surface (G =
-- depth, B = surface height) and ultimateShader.glsl tints those pixels.
-- Shallow water is drawn as rounded puddles that merge with wet neighbours,
-- using the water map texture (see WATER MAP below and the shader).
-- Order matters there: a pit's front rim, or a cliff in front, must cover
-- water behind it. The static terrain mesh is drawn first, so for every
-- column that has water we redraw that column again from the first wet row
-- onward, back to front, with the water surfaces slotted in after their own
-- tile. Tiles only overlap within a column, so that reproduces exactly the
-- right order.

local water = {}
package.loaded[...] = water  -- register now, so modules that require each other share this table

local canvas = require("src.canvas")
local terrain = require("src.terrain")

water.castAmount = 8      -- px of water added per W press (a quarter tile)
water.maxDepth   = 320    -- px; a single tile can't hold more than this
water.flowRate   = 0.2    -- fraction of the surface difference moved per tick (<= 0.25 is stable)
water.minSpread  = 2      -- px; surface tension across level ground
water.minDepth   = 0.05   -- px; water thinner than this simply disappears

-- EVAPORATION: every wet tile loses this many px of depth per second (1 px
-- a minute). One press of water spreads into a puddle 1-2 px deep, so it
-- dries up in about 2 minutes; a full 2-deep pit (64 px) lasts about an
-- hour. Applied once a second (EVAPORATION_INTERVAL) rather than every tick.
-- 0 turns it off.
water.evaporationRate = 1 / 60
local EVAPORATION_INTERVAL = 1

local depth = {}          -- depth[row][col] = px, wet tiles only
local awake = false       -- is anything still flowing?
local seenVersion = nil   -- terrain.version we last simulated against
local overlayMesh = nil
local overlayDirty = true
local evaporationTimer = 0

-- WATER MAP: a tiny texture, one pixel per tile, holding each tile's water
-- depth (R = depth / 255, capped). The lighting shader reads it to draw
-- shallow water as rounded puddles that join up with their neighbours.
-- Updated along with the overlay.
water.map = nil
local mapData = nil
local mapWet = {}         -- tiles currently non-zero in mapData, to clear next time

local NEIGHBOURS = { {1, 0}, {-1, 0}, {0, 1}, {0, -1} }

local function onMap(c, r)
    return r >= 1 and r <= terrain.rows and c >= 1 and c <= terrain.cols
        and terrain.map[r] and terrain.map[r][c] ~= nil
end

local function setDepth(c, r, d)
    if d <= water.minDepth then
        if depth[r] then
            depth[r][c] = nil
            if next(depth[r]) == nil then depth[r] = nil end
        end
    else
        depth[r] = depth[r] or {}
        depth[r][c] = d
    end
end

-- Depth (px) of water on tile (col, row).
function water:depthAt(c, r)
    local row = depth[r]
    return row and row[c] or 0
end

-- Height (px) of the water surface on tile (col, row), or nil if it's dry.
function water:surfaceAt(c, r)
    local d = self:depthAt(c, r)
    if d <= 0 then return nil end
    return terrain:heightAtTile(c, r) + d
end

-- Adds `amount` px of water to tile (col, row).
function water:add(c, r, amount)
    if not onMap(c, r) then return end
    setDepth(c, r, math.min(self.maxDepth, self:depthAt(c, r) + amount))
    self:wake()
end

-- Removes all water (used by devtools between scenes).
function water:clear()
    depth = {}
    awake = false
    overlayDirty = true
end

-- How deep the water is around the player's feet: the water surface on his
-- tile minus the height of his feet (so it shrinks while he jumps). 0 if dry.
function water:depthAtFeet(wx, wy, feetHeight)
    local ts = terrain.tileSize
    local c, r = math.floor(wx / ts) + 1, math.floor(wy / ts) + 1
    local S = self:surfaceAt(c, r)
    if not S then return 0 end
    return math.max(0, S - feetHeight)
end

function water:wake()
    awake = true
    overlayDirty = true
end

-- Lowers every wet tile by `amount` px (evaporation).
local function evaporate(amount)
    for r, row in pairs(depth) do
        for c, d in pairs(row) do
            setDepth(c, r, d - amount)
        end
    end
    overlayDirty = true
end

-- One simulation step; call once per fixed tick with its dt. (dt may be
-- omitted, e.g. by tools settling water instantly: then nothing evaporates.)
-- Transfers are worked out from the current state for every tile first,
-- then applied together, so the result doesn't depend on the order tiles
-- are visited in.
function water:update(dt)
    if dt and self.evaporationRate > 0 and next(depth) then
        evaporationTimer = evaporationTimer + dt
        if evaporationTimer >= EVAPORATION_INTERVAL then
            evaporate(self.evaporationRate * evaporationTimer)
            evaporationTimer = 0
        end
    end

    if terrain.version ~= seenVersion then   -- land was dug or raised
        seenVersion = terrain.version
        self:wake()
    end
    if not awake then return end

    local moves, n = {}, 0
    for r, row in pairs(depth) do
        for c, d in pairs(row) do
            local H = terrain:heightAtTile(c, r)
            local S = H + d
            local first, total = n + 1, 0
            for _, o in ipairs(NEIGHBOURS) do
                local nc, nr = c + o[1], r + o[2]
                if onMap(nc, nr) then
                    local Hn = terrain:heightAtTile(nc, nr)
                    local dn = self:depthAt(nc, nr)
                    local diff = S - (Hn + dn)
                    -- Flows if: downhill, or into water already there (so a
                    -- pool levels out completely), or onto dry ground only
                    -- past the surface-tension threshold.
                    if diff > 0 and (Hn < H or dn > 0 or diff > self.minSpread) then
                        local amount = diff * self.flowRate
                        n = n + 1
                        moves[n] = { c, r, nc, nr, amount }
                        total = total + amount
                    end
                end
            end
            -- Can't give away more water than the tile has.
            if total > d then
                local scale = d / total
                for i = first, n do moves[i][5] = moves[i][5] * scale end
            end
        end
    end

    -- Sum each tile's net change, then apply once (exactly conserves water).
    local delta, biggest = {}, 0
    local function addDelta(c, r, v)
        delta[r] = delta[r] or {}
        delta[r][c] = (delta[r][c] or 0) + v
    end
    for i = 1, n do
        local m = moves[i]
        addDelta(m[1], m[2], -m[5])
        addDelta(m[3], m[4], m[5])
        if m[5] > biggest then biggest = m[5] end
    end
    for r, row in pairs(delta) do
        for c, v in pairs(row) do
            setDepth(c, r, math.min(self.maxDepth, self:depthAt(c, r) + v))
        end
    end

    if n > 0 then overlayDirty = true end
    if biggest < 0.01 then awake = false end   -- settled: sleep until woken
end

-- Builds a surface-map overlay mesh: for each wet column, that column's
-- terrain from its first wet row onward, with water surfaces slotted in
-- (see DRAWING above). With `level`, only tiles at or below that height are
-- included: the version for the pit focus layer (lighting.lua).
local function buildOverlay(level)
    local ts = terrain.tileSize
    local verts = {}
    local quad = terrain:quadWriter(verts)
    local function included(c, r)
        return level == nil or terrain:heightAtTile(c, r) <= level
    end

    -- Per column: first and last wet row, and the lowest water surface.
    local columns = {}
    for r, row in pairs(depth) do
        for c, d in pairs(row) do
            if included(c, r) then
                local col = columns[c]
                local S = terrain:heightAtTile(c, r) + d
                if not col then
                    columns[c] = { first = r, last = r, lowest = S }
                else
                    col.first = math.min(col.first, r)
                    col.last = math.max(col.last, r)
                    col.lowest = math.min(col.lowest, S)
                end
            end
        end
    end

    for c, col in pairs(columns) do
        -- Rows further forward whose terrain can reach up over the water.
        local reach = math.ceil((terrain.maxHeight - col.lowest) / ts) + 1
        for r = col.first, math.min(terrain.rows, col.last + reach) do
            if included(c, r) then
                terrain:emitTile(c, r, quad, true, false)   -- block (if any) goes after the water
                local d = water:depthAt(c, r)
                if d > 0 then
                    local H = terrain:heightAtTile(c, r)
                    local S = H + d
                    local x0, y0 = (c - 1) * ts, (r - 1) * ts
                    -- Water surface.
                    quad(x0, y0 - S, x0 + ts, y0 - S + ts, 0, S, S, d)
                    -- Its front (south) face, from the surface down to the
                    -- tile's floor: you look through it at the floor. Usually
                    -- hidden behind a pit's rim; shows through pit focus.
                    quad(x0, y0 + ts - S, x0 + ts, y0 + ts - H, 1, S, H, d)
                end
                if level == nil then terrain:emitBlock(c, r, quad) end   -- a block floats above the water
            end
        end
    end

    return terrain:newSurfaceMesh(verts)
end

-- The pit focus layer's overlay, cached for one level until water changes.
local focusOverlay = { level = nil, mesh = nil, stale = true }

-- Rewrites the water map texture: clears last time's wet tiles, writes the
-- current ones.
local function updateMap()
    if not mapData or mapData:getWidth() ~= terrain.cols or mapData:getHeight() ~= terrain.rows then
        mapData = love.image.newImageData(terrain.cols, terrain.rows, "rgba8")
        water.map = love.graphics.newImage(mapData)
        water.map:setFilter("nearest", "nearest")
        mapWet = {}
    end
    for _, t in ipairs(mapWet) do mapData:setPixel(t[1] - 1, t[2] - 1, 0, 0, 0, 1) end
    mapWet = {}
    for r, row in pairs(depth) do
        for c, d in pairs(row) do
            mapData:setPixel(c - 1, r - 1, math.min(255, math.ceil(d)) / 255, 0, 0, 1)
            mapWet[#mapWet + 1] = { c, r }
        end
    end
    water.map:replacePixels(mapData)
end

-- Draws the water overlay into canvas.surface (and refreshes the water map
-- texture). Call right after terrain:drawSurfaceMap.
local function drawOverlayMesh(mesh, target, cameraX, cameraY)
    if not mesh then return end
    love.graphics.setCanvas(target)
    love.graphics.setBlendMode("replace")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(mesh, -cameraX, -cameraY)
    love.graphics.setBlendMode("alpha")
end

function water:drawSurfaceOverlay(cameraX, cameraY)
    if overlayDirty or not water.map then
        overlayMesh = buildOverlay()
        updateMap()
        overlayDirty = false
        focusOverlay.stale = true
    end
    drawOverlayMesh(overlayMesh, canvas.surface, cameraX, cameraY)
end

-- Draws water in the pit focus layer into canvas.focusSurface. Call right
-- after terrain:drawFocusSurface (and after drawSurfaceOverlay this frame).
function water:drawFocusOverlay(level, cameraX, cameraY)
    if focusOverlay.stale or focusOverlay.level ~= level then
        focusOverlay.mesh = buildOverlay(level)
        focusOverlay.level = level
        focusOverlay.stale = false
    end
    drawOverlayMesh(focusOverlay.mesh, canvas.focusSurface, cameraX, cameraY)
end

-- Total water on the map (px of depth summed over tiles), for tests.
function water:total()
    local sum = 0
    for _, row in pairs(depth) do
        for _, d in pairs(row) do sum = sum + d end
    end
    return sum
end

return water
