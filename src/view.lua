-- view.lua
--
-- Camera zoom and getting the finished frame onto the window.
--
-- The game renders at a small "game view" size (window.width x
-- window.height, in art pixels), which is then scaled up to fill the
-- window. For crisp pixel art that scale should be a whole number, so every
-- art pixel becomes an exact square of screen pixels. So:
--
--   * Zoom comes in whole-number levels (Z = zoom in, X = zoom out).
--   * At each level the game view is sized so it exactly fills the window:
--     e.g. a 1280x800 window at 2x shows 640x400 art pixels; at 4x, 320x200.
--   * Changing level glides there over `zoomDuration` seconds. During the
--     glide the scene is rendered at the wider of the two levels' view
--     sizes and scaled by an in-between amount using a pixel-art-friendly
--     filter (shaders/pixelScaleShader.glsl), then it lands exactly on the
--     whole-number level.
--
-- Canvases are only rebuilt when the game view size actually changes: at
-- the start and end of a zoom, or when the window is resized.

view = {}

view.zoom         = 2       -- target zoom level (whole number)
view.displayZoom  = 2       -- zoom currently on screen (in between while gliding)
view.minZoom      = 1
view.zoomDuration = 0.2     -- seconds per zoom step

-- Smallest game view we'll allow, in art pixels. Caps the max zoom so you
-- can always see a reasonable area.
view.minViewWidth, view.minViewHeight = 240, 160

local zoomFrom, zoomT = 2, 1  -- glide start value and progress (0..1)

local function smoothstep(x)
    return x * x * (3 - 2 * x)
end

-- Largest zoom level that keeps the view at least minViewWidth x minViewHeight.
function view:maxZoom(appW, appH)
    return math.max(self.minZoom,
        math.floor(math.min(appW / self.minViewWidth, appH / self.minViewHeight)))
end

-- Game view size (art px) that fills an appW x appH window at a whole-number
-- zoom. Rounded up (so there's no gap at the edges) and to even numbers (so
-- the player stays exactly centred).
function view:sizeFor(zoom, appW, appH)
    local w = math.ceil(appW / zoom)
    local h = math.ceil(appH / zoom)
    return w + w % 2, h + h % 2
end

-- Makes window.width/height (and the canvases) match what we need to render.
-- While gliding, that's the more zoomed-out of the two levels involved.
function view:apply(appW, appH)
    local renderZoom = math.max(self.minZoom, math.floor(math.min(self.displayZoom, self.zoom) + 1e-6))
    local w, h = self:sizeFor(renderZoom, appW, appH)
    if w ~= window.width or h ~= window.height then
        window.width, window.height = w, h
        canvas:initialize(w, h)
    end
end

-- Zoom in (+1) or out (-1) one level.
function view:step(delta, appW, appH)
    local target = math.max(self.minZoom, math.min(self:maxZoom(appW, appH), self.zoom + delta))
    if target ~= self.zoom then
        zoomFrom, zoomT = self.displayZoom, 0
        self.zoom = target
    end
end

-- Advances the zoom glide. Call every frame (variable dt) before drawing.
function view:update(dt, appW, appH)
    if zoomT < 1 then
        zoomT = math.min(1, zoomT + dt / self.zoomDuration)
        self.displayZoom = zoomFrom + (self.zoom - zoomFrom) * smoothstep(zoomT)
    else
        self.displayZoom = self.zoom
    end
    self:apply(appW, appH)
end

-- Window resized: keep the zoom level valid and refit the view.
function view:resize(appW, appH)
    self.zoom = math.min(self.zoom, self:maxZoom(appW, appH))
    self.displayZoom, zoomT = self.zoom, 1
    self:apply(appW, appH)
end

-- Draws canvas.intermediate to the window, scaled and centred.
function view:present(appW, appH)
    local s = self.displayZoom
    local x = (appW - window.width * s) / 2
    local y = (appH - window.height * s) / 2
    if s == math.floor(s) then
        -- Whole-number zoom: snap to whole screen pixels so art pixels line
        -- up exactly with screen pixels.
        x, y = math.floor(x), math.floor(y)
    end

    local ps = shader.pixelScale
    love.graphics.setCanvas()
    love.graphics.setShader(ps)
    ps:send("texSize", {window.width, window.height})
    ps:send("scale", s)
    love.graphics.draw(canvas.intermediate, x, y, 0, s, s)
    love.graphics.setShader()
end
