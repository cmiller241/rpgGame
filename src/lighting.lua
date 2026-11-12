-- lighting.lua
--
-- Per-frame light state (sun + the player's lamp) and the final composite
-- pass that turns the ground, sprite and shadow canvases into the finished
-- frame. The heavy lifting is in shaders/ultimateShader.glsl.

lighting = {}

lighting.lampRadius = 100     -- px, how far the player's lamp reaches
lighting.lampHeight = 24      -- px above the player's feet (roughly hand height)

-- Filled in by lighting:begin() each frame.
lighting.sun = nil
lighting.lamp = { x = 0, y = 0, z = 0, radius = lighting.lampRadius }

-- Call once at the start of love.draw, before any sprites are drawn.
function lighting:begin()
    self.sun = sun:getState()

    -- The lamp sits at the player's feet position on the ground plane, raised
    -- to hand height. player.z is negative-up, so -player.z is the height.
    local lamp = self.lamp
    lamp.x = player.x + 16
    lamp.y = player.y - 4
    lamp.z = -player.z + self.lampHeight
    lamp.radius = self.lampRadius
end

-- Brightness multiplier for a sprite whose middle is at world (wx, wy) and
-- height h: the same lit/shadow level the shader gives the ground, so sprites
-- darken in a cliff's shadow and fade into dusk along with everything else.
-- Use with love.graphics.setColor.
function lighting:objectTint(wx, wy, h)
    local sunState = self.sun
    if sunState.litLevel <= sunState.shadowLevel then
        return sunState.litLevel                 -- no direct sun to block
    end
    local shade = terrain:sunShadowAmount(wx, wy, h, sunState)
    return sunState.litLevel + (sunState.shadowLevel - sunState.litLevel) * shade
end

-- Composites canvas.offscreen (+ object/shadow canvases) into
-- canvas.intermediate with lighting, shadows and colour grading applied.
function lighting:composite(cameraX, cameraY)
    local s, sunState, lamp = shader.ultimate, self.sun, self.lamp

    love.graphics.setCanvas(canvas.intermediate)
    love.graphics.setShader(s)

    terrain:sendUniforms(s, cameraX, cameraY)
    s:send("objectCanvas", canvas.object)
    s:send("shadowCanvas", canvas.shadow)

    s:send("sunDir", {sunState.dirX, sunState.dirY})
    s:send("sunSlope", sunState.slope)
    s:send("sunSoftness", sunState.softness)
    s:send("litLevel", sunState.litLevel)
    s:send("shadowLevel", sunState.shadowLevel)
    s:send("faceLight", sunState.faceLight)

    s:send("lampPos", {lamp.x, lamp.y, lamp.z})
    s:send("lampScreen", {lamp.x - cameraX, lamp.y - lamp.z - cameraY})
    s:send("lampRadius", lamp.radius)

    s:send("lutImage", sprites.lut)
    s:send("lutSize", {sprites.lut:getDimensions()})
    s:send("lutRowA", sunState.lutRowA)
    s:send("lutRowB", sunState.lutRowB)
    s:send("lutMix", sunState.lutMix)

    love.graphics.draw(canvas.offscreen, 0, 0)
    love.graphics.setShader()
end
