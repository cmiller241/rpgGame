-- shader.lua
--
-- Compiles every shader the game uses, once at startup.
--
-- Shaders that need to understand the world's 3D shape (lighting and sprite
-- shadows) get shaders/terrainCommon.glsl pasted in front of their own
-- source, since GLSL in LÖVE has no #include.

shader = {}

local terrainCommon = love.filesystem.read("shaders/terrainCommon.glsl")

local function load(path, needsTerrain)
    local source = love.filesystem.read(path)
    if needsTerrain then
        source = terrainCommon .. "\n" .. source
    end
    return love.graphics.newShader(source)
end

shader.ultimate      = load("shaders/ultimateShader.glsl", true)      -- final lighting/composite pass
shader.spriteShadow  = load("shaders/spriteShadowShader.glsl", true)  -- shadows cast by sprites
shader.surfaceDebug  = load("shaders/surfaceDebugShader.glsl")        -- C key: show surface map
shader.windSway      = load("shaders/windSwayShader.glsl")            -- tree canopy sway
shader.grass         = load("shaders/grassShader.glsl")               -- tall grass sway
shader.outline       = load("shaders/outlineShader.glsl")             -- highlight on pickups
shader.pixelScale    = load("shaders/pixelScaleShader.glsl")          -- crisp upscaling to the window

-- LÖVE throws an error if you send() a uniform that doesn't exist, and the
-- GLSL compiler deletes uniforms the shader never reads. This sends only if
-- the uniform survived compilation.
function shader.sendIfPresent(s, name, ...)
    if s:hasUniform(name) then
        s:send(name, ...)
    end
end
