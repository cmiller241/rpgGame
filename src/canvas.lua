-- canvas.lua
--
-- Off-screen render targets. All are the size of the game view
-- (window.width x window.height) except `temp`.
--
--   offscreen     ground tiles (grass, dirt, cliff faces)
--   object        sprites: player, trees, crops, pickups
--   shadow        sprite shadows (R = sun, G = lamp), see spriteShadow.lua
--   surface       per-pixel terrain shape (face/top + height), see terrain.lua
--   intermediate  the lit, colour-graded frame before it's scaled to the window
--   temp          200x200 scratch space for the player's current frame

local canvas = {}
package.loaded[...] = canvas  -- register now, so modules that require each other share this table

function canvas:initialize(cWidth, cHeight)
    canvas.object       = love.graphics.newCanvas(cWidth, cHeight)
    canvas.shadow       = love.graphics.newCanvas(cWidth, cHeight)
    canvas.offscreen    = love.graphics.newCanvas(cWidth, cHeight)
    canvas.intermediate = love.graphics.newCanvas(cWidth, cHeight)
    canvas.temp         = love.graphics.newCanvas(200, 200)

    -- The surface map stores heights, so it wants more precision than 8 bits
    -- per channel (8 bits would round heights to 4 px steps). Practically every
    -- desktop GPU supports rgba16f; fall back to rgba8 just in case.
    local formats = love.graphics.getCanvasFormats(true)
    local surfaceFormat = formats.rgba16f and "rgba16f" or "rgba8"
    canvas.surface = love.graphics.newCanvas(cWidth, cHeight, { format = surfaceFormat })
    canvas.surface:setFilter("nearest", "nearest")

    canvas.showSurfaceMap = canvas.showSurfaceMap or false
    -- Linear on purpose: pixelScaleShader relies on it to blend only the
    -- one-screen-pixel seams between art pixels (it's still pixel-perfect at
    -- whole-number zoom). See view.lua.
    canvas.intermediate:setFilter("linear", "linear")
end

-- Clears the per-frame canvases. (surface is cleared by terrain:drawSurfaceMap.)
function canvas:clear()
    for _, c in ipairs({canvas.object, canvas.shadow, canvas.offscreen, canvas.intermediate, canvas.temp}) do
        love.graphics.setCanvas(c)
        love.graphics.clear(0, 0, 0, 0)
    end
    love.graphics.setCanvas()
end

return canvas
