-- Initialize sprites table
sprites = {}

-- Load images
sprites.land = love.graphics.newImage("img/sprites2.png")
sprites.crop = love.graphics.newImage("img/crop.png")
sprites.tileBatch = love.graphics.newSpriteBatch(sprites.land, 1600)
sprites.grass = love.graphics.newImage("img/grass3.png")
sprites.tree = love.graphics.newImage("img/tree4.png")
sprites.treeBatch = love.graphics.newSpriteBatch(sprites.tree, 200)
sprites.cropBatch = love.graphics.newSpriteBatch(sprites.crop, 200)
sprites.treeShadowBatch = love.graphics.newSpriteBatch(sprites.tree, 200)
sprites.cropShadowBatch = love.graphics.newSpriteBatch(sprites.crop, 200)
sprites.tallgrassBatch = love.graphics.newSpriteBatch(sprites.tree, 1600)
sprites.grungeOverlay = love.graphics.newImage("img/grunge3.jpg")
sprites.lut = love.graphics.newImage("img/LUD2.png")
sprites.toolbar = love.graphics.newImage("img/toolbar.png")
sprites.objects = love.graphics.newImage("img/objects.png")
sprites.parchment = love.graphics.newImage("img/parchment.png")
sprites.textbox = love.graphics.newImage("img/textbox.png")
sprites.size = 32

-- Load quads for general sprites
sprites.spritesQuads = {}
for i = 1, math.ceil(sprites.land:getHeight() / sprites.size) do
    for j = 1, math.ceil(sprites.land:getWidth() / sprites.size) do
        sprites.spritesQuads[(i - 1) * math.ceil(sprites.land:getWidth() / sprites.size) + j] =
            love.graphics.newQuad((j-1) * sprites.size, (i-1) * sprites.size, sprites.size, sprites.size, sprites.land:getDimensions())
    end
end

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