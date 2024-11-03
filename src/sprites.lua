-- Initialize sprites table
sprites = {}

-- Load images
sprites.land = love.graphics.newImage("img/sprites2.png")
sprites.tileBatch = love.graphics.newSpriteBatch(sprites.land, 1600)
sprites.grass = love.graphics.newImage("img/grass3.png")
sprites.tree = love.graphics.newImage("img/tree3.png")
sprites.grungeOverlay = love.graphics.newImage("img/grunge3.jpg")
sprites.lut = love.graphics.newImage("img/LUD2.png")
sprites.size = 32

-- Load quads for general sprites
sprites.spritesQuads = {}
for i = 1, math.ceil(sprites.land:getHeight() / sprites.size) do
    for j = 1, math.ceil(sprites.land:getWidth() / sprites.size) do
        sprites.spritesQuads[(i - 1) * math.ceil(sprites.land:getWidth() / sprites.size) + j] =
            love.graphics.newQuad((j-1) * sprites.size, (i-1) * sprites.size, sprites.size, sprites.size, sprites.land:getDimensions())
    end
end

-- Create quads for tree and grass
--sprites.grassQuad = love.graphics.newQuad(61, 28, 7, 25, sprites.grass:getDimensions())
sprites.grassQuad = love.graphics.newQuad(0, 0, 32, 27, sprites.grass:getDimensions())
sprites.treeTrunk = love.graphics.newQuad(0, 0, 480, 480, sprites.tree:getDimensions())
sprites.treeFoliage = love.graphics.newQuad(480, 0, 480, 480, sprites.tree:getDimensions())
sprites.pineTree = love.graphics.newQuad(960, 0, 480, 480, sprites.tree:getDimensions())

