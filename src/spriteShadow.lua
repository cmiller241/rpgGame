-- spriteShadow.lua
--
-- Shadows cast by sprites (trees, crops, the player) onto the terrain,
-- including up the faces of cliffs.
--
-- Sprites call spriteShadow:add{...} while they're being drawn. After the
-- whole scene is drawn, spriteShadow:flush() renders every queued shadow into
-- canvas.shadow in a single pass (one canvas switch, one shader bind).
--
-- Waiting until the end matters for correctness, not just speed: the shadow
-- shader reads canvas.surface to know where cliff faces are, and that
-- canvas is complete before the first sprite is drawn. (Previously the colour
-- map was still being built while shadows were cast, so shadows falling onto
-- cliffs further down the screen were lost.)
--
-- See shaders/spriteShadowShader.glsl for the maths.

spriteShadow = {}

local queue = {}
local count = 0

-- Longest shadow (px) we'll draw a rectangle for. Very low sun angles would
-- otherwise cover the whole screen with a nearly invisible shadow.
local MAX_SHADOW_LENGTH = 600

function spriteShadow:clear()
    count = 0
end

-- Queue a sprite's shadow. Fields:
--   image        Image or Canvas the sprite lives in
--   quadX, quadY, quadW, quadH   sprite rectangle within that image (px)
--   anchorX, anchorY             px inside the quad where it touches the ground
--   worldX, worldY, worldZ       world position + ground height of the anchor
--   lift         (optional) px raised off the ground, e.g. jumping
--   opacity      (optional) 0..1 sun-shadow strength, default 1
--   castLamp     (optional) true if it should also block the player's lamp
function spriteShadow:add(c)
    count = count + 1
    queue[count] = c
end

-- Screen-space rectangle that contains every pixel this caster's shadow
-- could touch. Returns nil if it's entirely off screen.
local function shadowBounds(c, sunState, lamp, cameraX, cameraY)
    local ts = terrain
    -- How far the sprite reaches sideways from its anchor.
    local halfWidth = math.max(c.anchorX, c.quadW - c.anchorX)
    local spriteTop = c.anchorY + (c.lift or 0)  -- tallest point above the ground

    -- The sprite stands on a horizontal base line through its feet
    -- (worldX +- halfWidth, at worldY), see spriteShadowShader.glsl.
    local minX, maxX = c.worldX - halfWidth, c.worldX + halfWidth
    local minY, maxY = c.worldY - 1, c.worldY + 1
    local any = false

    if sunState.isUp and sunState.litLevel > sunState.shadowLevel then
        -- The sun is always on the camera side (dirY > 0), so the shadow runs
        -- from the base line away from the sun and never below the feet.
        -- Worst case it falls onto ground lower than the sprite's base, so
        -- the full sprite height plus its base height can be projected.
        local length = math.min((spriteTop + c.worldZ) / sunState.slope, MAX_SHADOW_LENGTH)
        local tipX = c.worldX - sunState.dirX * length
        local tipY = c.worldY - sunState.dirY * length
        -- Soft edges spread up to (distance * softness) px past the silhouette.
        local blur = length * sunState.softness + 1
        minX, maxX = math.min(minX, tipX - halfWidth - blur), math.max(maxX, tipX + halfWidth + blur)
        minY = math.min(minY, tipY - blur)
        any = true
    end

    if c.castLamp then
        local dx, dy = c.worldX - lamp.x, c.worldY - lamp.y
        if dx * dx + dy * dy < (lamp.radius + halfWidth) ^ 2 then
            minX, maxX = math.min(minX, lamp.x - lamp.radius), math.max(maxX, lamp.x + lamp.radius)
            minY, maxY = math.min(minY, lamp.y - lamp.radius), math.max(maxY, lamp.y + lamp.radius)
            any = true
        end
    end

    if not any then return nil end

    -- World ground-plane box -> screen box. Terrain at height h is drawn h px
    -- higher, so extend the top by the tallest terrain on the map.
    local x0 = math.max(0, math.floor(minX - cameraX))
    local x1 = math.min(window.width, math.ceil(maxX - cameraX))
    local y0 = math.max(0, math.floor(minY - cameraY - ts.maxHeight))
    local y1 = math.min(window.height, math.ceil(maxY - cameraY))
    if x1 <= x0 or y1 <= y0 then return nil end
    return x0, y0, x1 - x0, y1 - y0
end

-- Renders every queued shadow into canvas.shadow, then empties the queue.
function spriteShadow:flush(sunState, lamp, cameraX, cameraY)
    if count == 0 then return end
    local s = shader.spriteShadow

    love.graphics.setCanvas(canvas.shadow)
    love.graphics.setShader(s)
    love.graphics.setBlendMode("lighten", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)

    -- Per-frame uniforms.
    terrain:sendUniforms(s, cameraX, cameraY)
    s:send("sunUp", sunState.isUp and 1 or 0)
    s:send("sunDir", {sunState.dirX, sunState.dirY})
    s:send("sunSlope", sunState.slope)
    s:send("sunSoftness", sunState.softness)
    s:send("lampPos", {lamp.x, lamp.y, lamp.z})
    s:send("lampRadius", lamp.radius)

    -- Per-caster uniforms.
    for i = 1, count do
        local c = queue[i]
        local x, y, w, h = shadowBounds(c, sunState, lamp, cameraX, cameraY)
        if x then
            s:send("casterImage", c.image)
            s:send("casterImageSize", {c.image:getDimensions()})
            s:send("casterQuad", {c.quadX, c.quadY, c.quadW, c.quadH})
            s:send("casterAnchor", {c.anchorX, c.anchorY})
            s:send("casterBase", {c.worldX, c.worldY, c.worldZ})
            s:send("casterLift", c.lift or 0)
            s:send("casterOpacity", c.opacity or 1)
            s:send("castLampShadow", c.castLamp and 1 or 0)
            love.graphics.rectangle("fill", x, y, w, h)
        end
        queue[i] = nil
    end
    count = 0

    love.graphics.setBlendMode("alpha")
    love.graphics.setShader()
end
