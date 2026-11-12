-- camera.lua
--
-- Follows the player with a slight smoothing lag, and stops at the edges of
-- the map so you never see past them.
--
-- camera.x / camera.y are the world position of the game view's top-left
-- pixel. They're kept as decimals for smooth motion; camera:get() returns
-- them rounded to whole pixels for drawing (pixel art must sit on whole
-- pixels, or it shimmers).

local camera = {}
package.loaded[...] = camera  -- register now, so modules that require each other share this table

local player = require("src.player")
local sprites = require("src.sprites")
local terrain = require("src.terrain")
local window = require("src.window")

camera.x, camera.y = 0, 0

-- How quickly the camera catches up with the player. Higher = tighter.
-- 0 = locked exactly to the player with no smoothing.
camera.smoothing = 12

local initialised = false

-- Where the camera would like to be: player centred in the view.
local function target()
    return player.drawX + 16 - window.width / 2,
           player.drawY - window.height / 2
end

-- Keeps the view inside the map. If the map is smaller than the view along
-- an axis, centre the map on that axis instead.
local function clamp(x, y)
    local mapW = terrain.cols * sprites.size
    local mapH = terrain.rows * sprites.size
    if mapW <= window.width then
        x = (mapW - window.width) / 2
    else
        x = math.max(0, math.min(x, mapW - window.width))
    end
    if mapH <= window.height then
        y = (mapH - window.height) / 2
    else
        y = math.max(0, math.min(y, mapH - window.height))
    end
    return x, y
end

-- Call once per frame (variable dt) after the player's draw position is set.
function camera:update(dt)
    local tx, ty = target()
    if not initialised or self.smoothing <= 0 then
        self.x, self.y = tx, ty
        initialised = true
    else
        -- Frame-rate independent exponential follow.
        local k = 1 - math.exp(-self.smoothing * dt)
        self.x = self.x + (tx - self.x) * k
        self.y = self.y + (ty - self.y) * k
    end
    self.x, self.y = clamp(self.x, self.y)
end

-- Jump straight to the player (e.g. after teleporting or changing zoom).
function camera:snap()
    self.x, self.y = clamp(target())
end

-- Whole-pixel camera position for drawing.
function camera:get()
    return math.floor(self.x + 0.5), math.floor(self.y + 0.5)
end

return camera
