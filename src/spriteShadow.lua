-- spriteShadow.lua
--
-- Shadows cast by sprites (trees, crops, pages, the player).
--
-- Sprites call spriteShadow:add(caster) while the scene is being built.
-- Then:
--   * spriteShadow:flush() draws every caster's shadow onto canvas.shadow
--     for the terrain to receive. Casters that share a sprite sheet go out
--     in ONE draw call: each caster becomes a rectangle in a single mesh,
--     with that caster's details stored on its vertices (see
--     spriteShadowShader.glsl).
--   * spriteShadow:sunShadowAt() answers the same question on the CPU for
--     a single point, so sprites standing in another sprite's shadow (e.g.
--     the player under a tree) can be darkened.
--
-- The list is cleared at the start of each frame with spriteShadow:clear().

local spriteShadow = {}
package.loaded[...] = spriteShadow  -- register now, so modules that require each other share this table

local canvas = require("src.canvas")
local shader = require("src.shader")
local terrain = require("src.terrain")
local window = require("src.window")

local casters = {}
local count = 0

-- Longest shadow (px) we'll draw a rectangle for.
local MAX_SHADOW_LENGTH = 600

function spriteShadow:clear()
    for i = count, 1, -1 do casters[i] = nil end
    count = 0
end

-- Queue a caster. Fields:
--   image        Image or Canvas the sprite lives in
--   data         (optional) ImageData copy of `image`, needed for sunShadowAt
--   quadX, quadY, quadW, quadH   sprite rectangle within that image (px)
--   anchorX, anchorY             px inside the quad where it touches the ground
--   worldX, worldY, worldZ       world position + ground height of the anchor
--   lift         (optional) px raised off the ground, e.g. jumping
--   opacity      (optional) 0..1 sun-shadow strength, default 1
--   castLamp     (optional) true to also block the player's lamp
--   swayPx, swayAnchor  (optional) wind sway: px shift at the sprite's top,
--                and where the bend starts (fraction down the quad)
function spriteShadow:add(c)
    count = count + 1
    casters[count] = c
end

-------------------------------------------------------------------------------
-- GPU: draw all shadows onto canvas.shadow
-------------------------------------------------------------------------------

-- Screen-space rectangle that contains every pixel this caster's shadow
-- could touch, or nil if it's entirely off screen.
local function shadowBounds(c, sunState, lamp, cameraX, cameraY)
    -- How far the sprite (plus sway) reaches sideways from its anchor.
    local halfWidth = math.max(c.anchorX, c.quadW - c.anchorX) + math.abs(c.swayPx or 0)
    local spriteTop = c.anchorY + (c.lift or 0)  -- tallest point above the ground

    -- The sprite stands on a horizontal base line through its feet
    -- (worldX +- halfWidth, at worldY), see spriteShadowShader.glsl.
    local minX, maxX = c.worldX - halfWidth, c.worldX + halfWidth
    local minY, maxY = c.worldY - 1, c.worldY + 1
    local any = false

    if sunState.isUp and sunState.litLevel > sunState.shadowLevel then
        -- The sun is always on the camera side (dirY > 0), so the shadow runs
        -- from the base line away from the sun and never below the feet.
        -- Worst case it falls onto the lowest ground on the map (the floor
        -- of the deepest pit), so project the sprite's full height above that.
        local length = math.min((spriteTop + c.worldZ - terrain.minHeight) / sunState.slope, MAX_SHADOW_LENGTH)
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
    -- higher, so extend the top by the tallest terrain on the map and the
    -- bottom by the deepest pit.
    local x0 = math.max(0, math.floor(minX - cameraX))
    local x1 = math.min(window.width, math.ceil(maxX - cameraX))
    local y0 = math.max(0, math.floor(minY - cameraY - terrain.maxHeight))
    local y1 = math.min(window.height, math.ceil(maxY - cameraY - terrain.minHeight))
    if x1 <= x0 or y1 <= y0 then return nil end
    return x0, y0, x1, y1
end

-- Mesh of rectangles, one per caster. Each vertex carries its caster's
-- details as extra attributes (names must match spriteShadowShader.glsl).
local VERTEX_FORMAT = {
    {"VertexPosition",   "float", 2},
    {"CasterQuad",       "float", 4},   -- quad x, y, w, h in the image (px)
    {"CasterAnchorLift", "float", 4},   -- anchor x, anchor y, lift, sun-shadow opacity
    {"CasterBase",       "float", 4},   -- world x, y, height of the anchor; castLamp (0/1)
    {"CasterSway",       "float", 2},   -- sway px at the top, bend start (fraction down)
}
local mesh, meshCapacity = nil, 0
local vertices = {}

local function ensureCapacity(n)
    if n <= meshCapacity then return end
    meshCapacity = math.max(n, meshCapacity * 2, 600)
    mesh = love.graphics.newMesh(VERTEX_FORMAT, meshCapacity, "triangles", "stream")
end

-- Writes the 6 vertices (two triangles) of one caster's rectangle.
local function pushRect(n, c, x0, y0, x1, y1)
    local quadX, quadY, quadW, quadH = c.quadX, c.quadY, c.quadW, c.quadH
    local ax, ay, lift, op = c.anchorX, c.anchorY, c.lift or 0, c.opacity or 1
    local bx, by, bz, lamp = c.worldX, c.worldY, c.worldZ, c.castLamp and 1 or 0
    local sw, sa = c.swayPx or 0, c.swayAnchor or 1
    local corners = { x0, y0, x1, y0, x0, y1, x1, y0, x1, y1, x0, y1 }
    for i = 1, 6 do
        local v = vertices[n + i]
        if not v then v = {}; vertices[n + i] = v end
        v[1], v[2] = corners[i * 2 - 1], corners[i * 2]
        v[3], v[4], v[5], v[6] = quadX, quadY, quadW, quadH
        v[7], v[8], v[9], v[10] = ax, ay, lift, op
        v[11], v[12], v[13], v[14] = bx, by, bz, lamp
        v[15], v[16] = sw, sa
    end
    return n + 6
end

-- Renders every queued shadow into canvas.shadow: one draw call per sprite sheet.
function spriteShadow:flush(sunState, lamp, cameraX, cameraY)
    if count == 0 then return end

    -- Group casters by image, building one vertex list with a range per image.
    local groups, order = {}, {}
    for i = 1, count do
        local c = casters[i]
        local g = groups[c.image]
        if not g then
            g = {}
            groups[c.image] = g
            order[#order + 1] = c.image
        end
        g[#g + 1] = c
    end

    local n, ranges = 0, {}
    for _, image in ipairs(order) do
        local first = n + 1
        for _, c in ipairs(groups[image]) do
            local x0, y0, x1, y1 = shadowBounds(c, sunState, lamp, cameraX, cameraY)
            if x0 then n = pushRect(n, c, x0, y0, x1, y1) end
        end
        if n >= first then ranges[#ranges + 1] = { image, first, n - first + 1 } end
    end
    if n == 0 then return end

    ensureCapacity(n)
    -- Trim stale vertices past n so setVertices only uploads this frame's.
    for i = #vertices, n + 1, -1 do vertices[i] = nil end
    mesh:setVertices(vertices, 1)

    local s = shader.spriteShadow
    love.graphics.setCanvas(canvas.shadow)
    love.graphics.setShader(s)
    love.graphics.setBlendMode("lighten", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)

    terrain:sendUniforms(s, cameraX, cameraY)
    s:send("sunUp", sunState.isUp and 1 or 0)
    s:send("sunDir", {sunState.dirX, sunState.dirY})
    s:send("sunSlope", sunState.slope)
    s:send("sunSoftness", sunState.softness)
    s:send("lampPos", {lamp.x, lamp.y, lamp.z})
    s:send("lampRadius", lamp.radius)

    for _, r in ipairs(ranges) do
        local image, first, len = r[1], r[2], r[3]
        s:send("casterImage", image)
        s:send("casterImageSize", {image:getDimensions()})
        mesh:setDrawRange(first, len)
        love.graphics.draw(mesh)
    end
    mesh:setDrawRange()

    love.graphics.setBlendMode("alpha")
    love.graphics.setShader()
end

-------------------------------------------------------------------------------
-- CPU: is a single point in a sprite's sun shadow?
-------------------------------------------------------------------------------

-- 0..1: how strongly any queued caster (other than `exclude`) blocks the sun
-- for world point (wx, wy) at height h. Mirrors hitsBillboard() in
-- spriteShadowShader.glsl with a single sample (no soft edge). Casters
-- without CPU image data (the player) are skipped.
function spriteShadow:sunShadowAt(wx, wy, h, exclude, sunState)
    if not sunState.isUp or math.abs(sunState.dirY) < 0.001 then return 0 end
    local best = 0
    for i = 1, count do
        local c = casters[i]
        if c ~= exclude and c.data then
            local t = (c.worldY - wy) / sunState.dirY        -- distance to the billboard plane
            if t > 0 then
                local lateral = wx + sunState.dirX * t - c.worldX
                local heightAbove = h + t * sunState.slope - c.worldZ - (c.lift or 0)
                local px = c.anchorX + lateral
                local py = c.anchorY - heightAbove
                if py >= 0 and py < c.quadH then
                    -- Same wind bend as the canopy (see windSwayShader.glsl).
                    if c.swayPx then
                        local bend = math.max(0, math.min(1, (c.swayAnchor - py / c.quadH) / c.swayAnchor))
                        px = px - c.swayPx * bend * bend
                    end
                    if px >= 0 and px < c.quadW then
                        local _, _, _, a = c.data:getPixel(c.quadX + math.floor(px), c.quadY + math.floor(py))
                        if a > 0.5 then
                            best = math.max(best, c.opacity or 1)
                            if best >= 1 then return 1 end
                        end
                    end
                end
            end
        end
    end
    return best
end

return spriteShadow
