-- Initialize sprites table
local sprites = {}
package.loaded[...] = sprites  -- register now, so modules that require each other share this table

-- Load images

-- The ground tile sheet. Floating-block art (img/block.png: 32x64, top face
-- above front face) is appended underneath it at load time, so blocks can
-- go in the same tile batch as everything else (one texture per batch).
-- Existing tile numbers are unchanged; see sprites.blockTopQuad below.
--
-- The tile batch draws from sprites.land, a Canvas: the sheet is copied into
-- its top-left corner, and the space below holds warped copies of tiles on
-- slopes (see SLOPED TILES at the bottom), so they're one sprite each in
-- the same batch. sprites.landImage is the plain sheet the copies are made
-- from (a canvas can't be drawn into itself).
local LAND_W, LAND_H = 2048, 4096
do
    local sheet = love.image.newImageData("img/sprites2.png")
    local block = love.image.newImageData("img/block.png")
    local combined = love.image.newImageData(sheet:getWidth(), sheet:getHeight() + block:getHeight())
    combined:paste(sheet, 0, 0, 0, 0, sheet:getWidth(), sheet:getHeight())
    combined:paste(block, 0, sheet:getHeight(), 0, 0, block:getWidth(), block:getHeight())
    sprites.landImage = love.graphics.newImage(combined)
    sprites.blockSheetY = sheet:getHeight()   -- where the block art starts in sprites.land

    sprites.land = love.graphics.newCanvas(LAND_W, LAND_H, { dpiscale = 1 })
    sprites.land:setFilter("nearest", "nearest")
end

-- (Re)fills sprites.land: the sheet in the corner, no warped tiles yet.
-- A canvas loses its contents when the window mode changes
-- (love.window.setMode), so call this after any mode change.
local forgetWarpedTiles   -- defined with the slot cache below
function sprites.restoreLand()
    love.graphics.push("all")
    love.graphics.setCanvas(sprites.land)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setBlendMode("replace", "premultiplied")   -- copy pixels exactly (no alpha multiply)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(sprites.landImage, 0, 0)
    love.graphics.pop()
    if forgetWarpedTiles then forgetWarpedTiles() end
end
sprites.restoreLand()
sprites.crop = love.graphics.newImage("img/crop.png")
-- All ground tiles for a frame (grass, dirt, cliff faces) go into this one
-- batch and are drawn in a single call. Grows automatically if needed.
sprites.tileBatch = love.graphics.newSpriteBatch(sprites.land, 1600)
-- While the player is down in a pit, the tiles at or below his level are
-- also drawn into this batch, as a separate layer the lighting pass can
-- show through higher ground (see lighting.lua, "pit focus").
sprites.focusBatch = love.graphics.newSpriteBatch(sprites.land, 400)
sprites.grass = love.graphics.newImage("img/grass3.png")
sprites.tree = love.graphics.newImage("img/tree4.png")
sprites.grungeOverlay = love.graphics.newImage("img/grunge3.jpg")
-- Colour-grading lookup table: four 32-row blocks (noon, dusk, night, dawn).
-- Must be sampled exactly, never blurred.
sprites.lut = love.graphics.newImage("img/LUD2.png")
sprites.lut:setFilter("nearest", "nearest")
sprites.toolbar = love.graphics.newImage("img/toolbar.png")
sprites.objects = love.graphics.newImage("img/objects.png")
sprites.parchment = love.graphics.newImage("img/parchment.png")
sprites.textbox = love.graphics.newImage("img/textbox.png")
sprites.size = 32

-- CPU-readable copies of the sprite sheets that cast shadows, so Lua can
-- check whether one sprite is standing in another's shadow (see
-- spriteShadow:sunShadowAt).
sprites.treeData    = love.image.newImageData("img/tree4.png")
sprites.cropData    = love.image.newImageData("img/crop.png")
sprites.objectsData = love.image.newImageData("img/objects.png")

-- Load quads for general sprites
-- Tile numbers follow the sheet's own layout (11 per row); the quads point
-- into sprites.land, which has the sheet in its top-left corner.
sprites.spritesQuads = {}
do
    local perRow = math.ceil(sprites.landImage:getWidth() / sprites.size)
    for i = 1, math.ceil(sprites.landImage:getHeight() / sprites.size) do
        for j = 1, perRow do
            sprites.spritesQuads[(i - 1) * perRow + j] =
                love.graphics.newQuad((j-1) * sprites.size, (i-1) * sprites.size, sprites.size, sprites.size, sprites.land:getDimensions())
        end
    end
end

-- Floating block faces (see the note at the top of this file).
sprites.blockTopQuad   = love.graphics.newQuad(0, sprites.blockSheetY, 32, 32, sprites.land:getDimensions())
sprites.blockFrontQuad = love.graphics.newQuad(0, sprites.blockSheetY + 32, 32, 32, sprites.land:getDimensions())

-- Load quads for crops
sprites.cropQuads = {}
for i = 1, math.ceil(sprites.crop:getHeight() / 112) do
    for j = 1, math.ceil(sprites.crop:getWidth() / 112) do
        sprites.cropQuads[(i - 1) * math.ceil(sprites.crop:getWidth() / 112) + j] =
            love.graphics.newQuad((j-1) * 112, (i-1) * 112, 112, 112, sprites.crop:getDimensions())
    end
end


-- Load quads for toolbar sprites
sprites.toolbarQuads = {}
for i = 1, math.ceil(sprites.toolbar:getHeight() / 60) do
    for j = 1, math.ceil(sprites.toolbar:getWidth() / 60) do
        sprites.toolbarQuads[(i - 1) * math.ceil(sprites.toolbar:getWidth() / 60) + j] =
            love.graphics.newQuad((j-1) * 60, (i-1) * 60, 60, 60, sprites.toolbar:getDimensions())
    end
end

-- Create quads for tree and grass
sprites.grassQuad = love.graphics.newQuad(0, 0, 32, 27, sprites.grass:getDimensions())
sprites.treeTrunk = love.graphics.newQuad(0, 0, 480, 480, sprites.tree:getDimensions())
sprites.treeFoliage = love.graphics.newQuad(480, 0, 480, 480, sprites.tree:getDimensions())
sprites.pineTree = love.graphics.newQuad(960, 0, 480, 480, sprites.tree:getDimensions())

-- Load quads for objects spritesheet (640x640, 64x64 tiles)
sprites.objectQuads = {}
for i = 1, math.ceil(sprites.objects:getHeight() / 64) do
    for j = 1, math.ceil(sprites.objects:getWidth() / 64) do
        sprites.objectQuads[(i - 1) * math.ceil(sprites.objects:getWidth() / 64) + j] =
            love.graphics.newQuad((j-1) * 64, (i-1) * 64, 64, 64, sprites.objects:getDimensions())
    end
end

-- Bible page animation frame
sprites.biblePageCenter = sprites.objectQuads[1] -- First frame: centered

-- SLOPED TILES (see SLOPES in terrain.lua)
-- In the 3/4 view, height only moves things up the screen, never sideways.
-- So a tile on a slope is drawn exactly by splitting it into 32 one-pixel
-- columns and stretching each between its north edge, middle line and
-- south edge (terrain.edgeHeights); with nearest filtering the pixel art
-- stays crisp.
--
-- Drawing those columns every frame would be dozens of sprites per tile, so
-- each warped tile (a sprite on a particular slope) is drawn ONCE into a
-- free slot of sprites.land below the sheet, and from then on it's a single
-- sprite in the tile batch. Slots are found by the sprite and the tile's
-- five heights, so they're reused across terrain rebuilds for every tile
-- whose shape didn't change. If the slots run out, all of them are
-- forgotten and refilled with whatever is on screen.

local scratchQuad = love.graphics.newQuad(0, 0, 1, 1, 1, 1)

-- Adds column u (0-based) of `quad` to `batch`, leaving out the top `skip`
-- source pixels, with its top-left at (x, y), stretched vertically by sy.
-- SpriteBatch:add copies the quad's texture coordinates when called, so
-- re-pointing one scratch quad for every column is safe.
function sprites.addColumn(batch, quad, u, skip, x, y, sy)
    local qx, qy, _, qh = quad:getViewport()
    local tw, th = quad:getTextureDimensions()
    scratchQuad:setViewport(qx + u, qy + skip, 1, qh - skip, tw, th)
    batch:add(scratchQuad, x, y, 0, 1, sy)
end

-- The warped columns of a tile sprite (sheet viewport qx, qy, 32 x qh) on
-- a top with surface points k, for a tile whose ground-level top-left is at
-- (x, y). Calls emit(srcX, srcY, srcH, destX, destY, destH) per piece.
local terrain   -- required on first use (terrain.lua is loaded after sprites.lua)
local function warpColumns(qx, qy, qh, x, y, k, emit)
    local ts = sprites.size
    local half = qh / 2
    for u = 0, ts - 1 do
        local n, m, s = terrain.edgeHeights(k, (u + 0.5) / ts)
        local top = y - math.floor(n + 0.5)
        local mid = y + ts / 2 - math.floor(m + 0.5)
        local bottom = y + ts - math.floor(s + 0.5)
        if math.abs((mid - top) - (bottom - mid)) < 0.5 then
            if bottom > top then emit(qx + u, qy, qh, x + u, top, bottom - top) end
        else
            -- The middle line bends (e.g. a lone raised tile peaks there): two halves.
            if mid > top then emit(qx + u, qy, half, x + u, top, mid - top) end
            if bottom > mid then emit(qx + u, qy + half, half, x + u, mid, bottom - mid) end
        end
    end
end

-- Slot cache. Slots are SLOT_W x SLOT_H, filling sprites.land below the sheet.
local SLOT_W, SLOT_H = 32, 128
local SLOT_TOP = 64     -- tile ground level sits this far down a slot (room for rises)
local slotX0, slotY0 = 0, math.ceil((sprites.blockSheetY + 64) / SLOT_H) * SLOT_H
local slotsPerRow = math.floor(LAND_W / SLOT_W)
local slotCount = slotsPerRow * math.floor((LAND_H - slotY0) / SLOT_H)
local slotByKey, nextSlot = {}, 0
local slotQuads = {}           -- slot index -> Quad (made once, reused)
local renderBatch = love.graphics.newSpriteBatch(sprites.landImage, 256, "stream")

-- Draws the warped sprite into slot `i`. Returns its quad, or nil if the
-- tile reaches outside a slot (very steep or tall).
local function renderSlot(i, quad, k)
    local qx, qy, _, qh = quad:getViewport()
    local sx = slotX0 + (i % slotsPerRow) * SLOT_W
    local sy = slotY0 + math.floor(i / slotsPerRow) * SLOT_H
    local fits = true
    renderBatch:clear()
    warpColumns(qx, qy, qh, 0, SLOT_TOP, k, function(srcX, srcY, srcH, dx, dy, dh)
        if dy < 0 or dy + dh > SLOT_H then fits = false return end
        scratchQuad:setViewport(srcX, srcY, 1, srcH, sprites.landImage:getDimensions())
        renderBatch:add(scratchQuad, dx, dy, 0, 1, dh / srcH)
    end)
    if not fits then return nil end
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setCanvas(sprites.land)
    love.graphics.setScissor(sx, sy, SLOT_W, SLOT_H)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setScissor()
    love.graphics.setBlendMode("replace", "premultiplied")   -- copy pixels exactly (no alpha multiply)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(renderBatch, sx, sy)
    love.graphics.pop()
    slotQuads[i] = slotQuads[i] or love.graphics.newQuad(sx, sy, SLOT_W, SLOT_H, sprites.land:getDimensions())
    return slotQuads[i]
end

-- The cached warped sprite for `quad` on surface k: a quad into
-- sprites.land, or false if it doesn't fit a slot. Memoised on k itself
-- (k tables are rebuilt when terrain changes), keyed by value otherwise.
local generation = 0

-- Forgets every slot (after sprites.land was wiped, or when slots run out).
forgetWarpedTiles = function()
    slotByKey, nextSlot = {}, 0
    generation = generation + 1
end

local function cachedWarp(quad, k)
    local memo = k.warped
    if memo and memo.generation == generation and memo[quad] ~= nil then return memo[quad] end
    if not memo or memo.generation ~= generation then
        memo = { generation = generation }
        k.warped = memo
        k.warpKey = k.warpKey or table.concat({ k[1], k[2], k[3], k[4], k[5] }, ",")
    end
    local key = tostring(quad) .. "|" .. k.warpKey
    local entry = slotByKey[key]
    if entry == nil then
        if nextSlot >= slotCount then
            -- Out of slots: forget them all; whatever is on screen refills them.
            forgetWarpedTiles()
            memo = { generation = generation }
            k.warped = memo
        end
        entry = renderSlot(nextSlot, quad, k) or false
        if entry then nextSlot = nextSlot + 1 end
        slotByKey[key] = entry
    end
    memo[quad] = entry
    return entry
end

-- Adds a 32 px tile sprite onto a top with surface points k (terrain:
-- cornersOf). (x, y) is where the tile is at ground level. Flat tops are a
-- single quad, exactly as before; sloped ones are one cached warped sprite
-- (or, if it doesn't fit a slot, drawn column by column).
function sprites.addOnTop(batch, quad, x, y, k)
    if k.flat then
        batch:add(quad, x, y - k[1])
        return
    end
    terrain = terrain or require("src.terrain")
    local warped = cachedWarp(quad, k)
    if warped then
        batch:add(warped, x, y - SLOT_TOP)
        return
    end
    local qx, qy, _, qh = quad:getViewport()
    local tw, th = quad:getTextureDimensions()
    warpColumns(qx, qy, qh, x, y, k, function(srcX, srcY, srcH, dx, dy, dh)
        scratchQuad:setViewport(srcX, srcY, 1, srcH, tw, th)
        batch:add(scratchQuad, dx, dy, 0, 1, dh / srcH)
    end)
end

return sprites
