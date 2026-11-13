-- Initialize sprites table
local sprites = {}
package.loaded[...] = sprites  -- register now, so modules that require each other share this table

-- Load images

-- The ground tile sheet. Floating-block art (img/block.png: 32x64, top face
-- above front face) is appended underneath it at load time, so blocks can
-- go in the same tile batch as everything else (one texture per batch).
-- Existing tile numbers are unchanged; see sprites.blockTopQuad below.
do
    local sheet = love.image.newImageData("img/sprites2.png")
    local block = love.image.newImageData("img/block.png")
    local combined = love.image.newImageData(sheet:getWidth(), sheet:getHeight() + block:getHeight())
    combined:paste(sheet, 0, 0, 0, 0, sheet:getWidth(), sheet:getHeight())
    combined:paste(block, 0, sheet:getHeight(), 0, 0, block:getWidth(), block:getHeight())
    sprites.land = love.graphics.newImage(combined)
    sprites.blockSheetY = sheet:getHeight()   -- where the block art starts in sprites.land
end
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
sprites.spritesQuads = {}
for i = 1, math.ceil(sprites.land:getHeight() / sprites.size) do
    for j = 1, math.ceil(sprites.land:getWidth() / sprites.size) do
        sprites.spritesQuads[(i - 1) * math.ceil(sprites.land:getWidth() / sprites.size) + j] =
            love.graphics.newQuad((j-1) * sprites.size, (i-1) * sprites.size, sprites.size, sprites.size, sprites.land:getDimensions())
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

return sprites
