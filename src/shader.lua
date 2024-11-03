-- Create the shader table
shader = {}

-- Load shaders into the shader table
shader.gradient = love.graphics.newShader("shaders/gradientShader.glsl")
shader.lighten = love.graphics.newShader("shaders/lightShader.glsl")
shader.brighten = love.graphics.newShader("shaders/brightenShader.glsl")
shader.combined = love.graphics.newShader("shaders/combinedShader.glsl")
shader.leaves = love.graphics.newShader("shaders/leavesShader.glsl")
shader.grass = love.graphics.newShader("shaders/grassShader.glsl")
shader.shadow = love.graphics.newShader("shaders/shadowShader.glsl")
shader.shadowFromLight = love.graphics.newShader("shaders/shadowShaderFromLight.glsl")
shader.sprite = love.graphics.newShader("shaders/spriteShader.glsl")
shader.spotlight = love.graphics.newShader("shaders/spotlightShader.glsl")
shader.spriteFromLight = love.graphics.newShader("shaders/spriteShaderFromLight.glsl")
shader.lut = love.graphics.newShader("shaders/lutShader.glsl")
shader.ultimate = love.graphics.newShader("shaders/ultimateShader.glsl")
shader.ultimateSprite = love.graphics.newShader("shaders/ultimateSpriteShader.glsl")
shader.mask = love.graphics.newShader("shaders/maskShader.glsl")
