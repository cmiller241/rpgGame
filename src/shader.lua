-- shader.lua
--
-- Compiles every shader the game uses, once at startup.
--
-- Shaders that need to understand the world's 3D shape (lighting and sprite
-- shadows) get shaders/terrainCommon.glsl pasted in front of their own
-- source, since GLSL in LÖVE has no #include.

local shader = {}
package.loaded[...] = shader  -- register now, so modules that require each other share this table

local terrainCommon = love.filesystem.read("shaders/terrainCommon.glsl")

local function load(path, needsTerrain)
    local source = love.filesystem.read(path)
    if needsTerrain then
        -- Pixel stage only: it samples textures and is never needed by a
        -- vertex stage (spriteShadowShader.glsl has one).
        source = "#ifdef PIXEL\n" .. terrainCommon .. "\n#endif\n" .. source
    end
    return love.graphics.newShader(source)
end

shader.ultimate      = load("shaders/ultimateShader.glsl", true)      -- final lighting/composite pass
shader.spriteShadow  = load("shaders/spriteShadowShader.glsl", true)  -- shadows cast by sprites
shader.surfaceDebug  = load("shaders/surfaceDebugShader.glsl")        -- C key: show surface map
shader.windSway      = load("shaders/windSwayShader.glsl")            -- tree canopy sway
shader.outline       = load("shaders/outlineShader.glsl")             -- highlight on pickups
shader.sparkle       = load("shaders/sparkleShader.glsl")             -- motes of light around pages
shader.dust          = load("shaders/dustShader.glsl")                -- dust puffs at the player's feet
shader.ripple        = load("shaders/rippleShader.glsl")              -- ripple rings on water
shader.pixelScale    = load("shaders/pixelScaleShader.glsl")          -- crisp upscaling to the window

-- LÖVE throws an error if you send() a uniform that doesn't exist, and the
-- GLSL compiler deletes uniforms the shader never reads. This sends only if
-- the uniform survived compilation.
function shader.sendIfPresent(s, name, ...)
    if s:hasUniform(name) then
        s:send(name, ...)
    end
end

return shader
