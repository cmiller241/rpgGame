-- camera.lua
--
-- Follows the player with a slight smoothing lag, and stops at the edges of
-- the map so you never see past them.
--
-- HEIGHT: the player is drawn higher on screen the higher he is, so the
-- camera follows the height of what he's STANDING on, not his jumps:
--   * while he's in the air the camera ignores his height (jumping never
--     bobs the view);
--   * when he lands on higher or lower ground (a ledge, a block, a pit
--     floor), or walks up a slope, it eases to that level (heightSmoothing);
--   * if he's about to leave the screen anyway (e.g. falling off a tall
--     cliff), it follows just enough to keep his feet inside the view.
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

-- How quickly the camera settles on a new ground height after he lands
-- (lower = slower, gentler). 5 takes about half a second.
camera.heightSmoothing = 5

local TOP_MARGIN = 24        -- px his FEET are kept below the top of the view (a jump
                             -- may briefly clip his head at high zoom; that's fine)
local BOTTOM_MARGIN = 20     -- px his feet are kept above the bottom

camera.ground = 0            -- the ground height (px) the camera is framing
local groundTarget = 0       -- the height of what he last stood on

local initialised = false

-- The height of whatever he's standing on, updated only while he's on the
-- ground (so it holds still through a jump).
local function updateGroundTarget()
    if player.isOnGround then groundTarget = -player.drawZ end
end

-- Where the camera would like to be: player centred in the view, framed at
-- ground height `ground`.
local function target(ground)
    return player.drawX + 16 - window.width / 2,
           player.drawY - ground - window.height / 2
end

-- Moves camera y just enough to keep his feet inside the view (a safety
-- net: normally the ground-height framing above keeps him centred).
local function keepInView(y)
    local feet = player.drawY + player.drawZ          -- his feet's world y on screen (drawZ < 0 = up)
    if feet - TOP_MARGIN < y then y = feet - TOP_MARGIN end
    if feet + BOTTOM_MARGIN > y + window.height then y = feet + BOTTOM_MARGIN - window.height end
    return y
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
    updateGroundTarget()
    if not initialised or self.smoothing <= 0 then
        self.ground = groundTarget
        self.x, self.y = target(self.ground)
        initialised = true
    else
        -- Frame-rate independent exponential follow; the ground level eases
        -- more slowly, so landing on a ledge re-frames gently.
        self.ground = self.ground + (groundTarget - self.ground) * (1 - math.exp(-self.heightSmoothing * dt))
        local tx, ty = target(self.ground)
        local k = 1 - math.exp(-self.smoothing * dt)
        self.x = self.x + (tx - self.x) * k
        self.y = self.y + (ty - self.y) * k
    end
    self.y = keepInView(self.y)
    self.x, self.y = clamp(self.x, self.y)
end

-- Jump straight to the player (e.g. after teleporting or changing zoom).
function camera:snap()
    groundTarget = -player.drawZ                       -- frame wherever he is now
    self.ground = groundTarget
    local x, y = target(self.ground)
    self.x, self.y = clamp(x, keepInView(y))
end

-- Whole-pixel camera position for drawing.
function camera:get()
    return math.floor(self.x + 0.5), math.floor(self.y + 0.5)
end

return camera
