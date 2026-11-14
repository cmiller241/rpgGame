-- weather.lua
--
-- The weather: R cycles sunny (with drifting cloud shadows) -> rain -> fog
-- -> sunny. Each change eases over FADE_TIME seconds: weather.amount (rain)
-- and weather.fog each go 0..1, and everything scales with them.
--
-- RAIN:
--   * LIGHT (lighting.lua): the sun goes behind the overcast, so direct
--     sunlight and with it every sun shadow fades to a soft trace
--     (weather:overcast); the final frame is tinted a darker blue-grey and a
--     little desaturated (weatherTint / weatherAmount in ultimateShader.glsl).
--   * RAIN: slanted streaks fall through the view, each landing on the real
--     ground height under it (slopes, cliff tops, pit floors) with a tiny
--     splat, or a ripple ring when it lands in water (splash.lua). Drawn
--     after lighting, over everything (main.lua calls weather:draw).
--   * LIGHTNING: in heavy rain (day or night), a strike lights up the whole
--     scene: the first a few seconds after the rain fills in
--     (FIRST_STRIKE_MIN..MAX), then every STRIKE_GAP_MIN..MAX seconds: a bright pulse, a quick
--     flicker, and a slower fade (weather.flash, 0..1, sent to the shader
--     as lightningFlash).
--   * Other modules check weather.amount: no dust from his feet on wet
--     ground (dust.lua), fireflies stay hidden (fireflies.lua).
--
-- FOG (ultimateShader.glsl, fogAmount): fog pools in low ground. Every
-- pixel is fogged by how high it is: pits, the pond and valleys fill with
-- thick mist, ordinary ground sits in a light haze, and anything well above
-- the fog line (FOG_TOP in the shader) rises clear. Slow drifting wisps
-- (the cloud noise, moved by fogDrift) keep it from looking flat. The sun
-- goes soft behind it (weather:overcast), and its colour follows the time
-- of day (pale by day, dark at night).

local weather = {}
package.loaded[...] = weather  -- register now, so modules that require each other share this table

local camera = require("src.camera")
local canvas = require("src.canvas")
local clouds = require("src.clouds")
local terrain = require("src.terrain")
local water = require("src.water")
local window = require("src.window")
local splash = require("src.splash")

local MODES = { "clear", "rain", "fog" }
weather.mode = "clear"
weather.raining = false          -- (mode == "rain")
weather.amount = 0               -- rain: 0 = none, 1 = full (eases)
weather.fog = 0                  -- fog: 0 = none, 1 = full (eases)
weather.fogDrift = { 0, 0 }      -- how far the fog wisps have drifted (px)

local FADE_TIME = 3              -- s to change over
local OVERCAST = 0.2             -- fraction of direct sun left in full rain
local FOG_OVERCAST = 0.45        -- ... and in full fog
local FOG_DRIFT = { 9, 3 }       -- px/s the fog wisps move
weather.tint = { 0.70, 0.78, 0.92 }    -- colour multiplier in full rain
weather.desaturate = 0.25              -- how much colour drains out in full rain

local DROPS_PER_PX = 1 / 650     -- drops per square px of the view, in full rain
local FALL_SPEED = 520           -- px/s
local WIND_SLANT = 0.22          -- sideways px per px fallen (plus the cloud wind)
local START_HEIGHT = 260         -- px above the ground a drop starts (spread down from here)
local STREAK = 7                 -- streak length (px)
local DROP_COLOUR = { 0.78, 0.85, 0.98, 0.45 }
local SPLAT_TIME = 0.14          -- s a splat lasts
local MARGIN = 48                -- px around the view drops live in

local FIRST_STRIKE_MIN, FIRST_STRIKE_MAX = 3, 8   -- s after the rain fills in
local STRIKE_GAP_MIN, STRIKE_GAP_MAX = 8, 20      -- s between strikes after that
-- One strike: pulses at these times (s after it starts) and strengths, each
-- dying away at FLASH_DECAY. The first is the main bolt, the rest flicker.
local STRIKE_PULSES = {
    { { 0.00, 1.0 }, { 0.11, 0.55 }, { 0.19, 0.8 } },
    { { 0.00, 0.9 }, { 0.16, 0.5 } },
    { { 0.00, 0.7 }, { 0.07, 1.0 }, { 0.30, 0.35 } },
}
local FLASH_DECAY = 9            -- per second (a pulse is ~gone in 0.35 s)

weather.flash = 0                -- current lightning brightness, 0..1
local strike, strikeTime = nil, 0
local nextStrike = nil           -- s until the next strike (nil = not raining hard)

local dot = love.graphics.newImage(love.image.newImageData(1, 1, "rgba8", string.char(255, 255, 255, 255)))
local batch = love.graphics.newSpriteBatch(dot, 1200, "stream")

local drops, splats = {}, {}

-- Next weather in the cycle (the R key).
function weather:toggle()
    for i, m in ipairs(MODES) do
        if m == self.mode then self:set(MODES[i % #MODES + 1]) return end
    end
end

-- Changes to weather `mode` ("clear", "rain" or "fog"); it eases in.
function weather:set(mode)
    self.mode = mode
    self.raining = mode == "rain"
end

-- Starts a lightning strike now.
function weather:lightning()
    strike = STRIKE_PULSES[love.math.random(#STRIKE_PULSES)]
    strikeTime = 0
end

local function between(a, b) return a + love.math.random() * (b - a) end

-- Lightning: maybe start a strike, and work out this tick's brightness.
local function updateLightning(self, dt)
    if self.amount > 0.8 and self.raining then
        nextStrike = nextStrike or between(FIRST_STRIKE_MIN, FIRST_STRIKE_MAX)
        nextStrike = nextStrike - dt
        if nextStrike <= 0 then
            self:lightning()
            nextStrike = between(STRIKE_GAP_MIN, STRIKE_GAP_MAX)
        end
    else
        nextStrike = nil          -- the next downpour starts the countdown afresh
    end
    local f = 0
    if strike then
        strikeTime = strikeTime + dt
        for _, pulse in ipairs(strike) do
            local t = strikeTime - pulse[1]
            if t >= 0 then f = math.max(f, pulse[2] * math.exp(-FLASH_DECAY * t)) end
        end
        if strikeTime > strike[#strike][1] + 0.8 then strike = nil end
    end
    self.flash = f * self.amount
end

-- A drop somewhere over the view (world x, y, height above the ground there).
local function newDrop(spreadDown)
    local cx, cy = camera:get()
    local x = cx - MARGIN + love.math.random() * (window.width + MARGIN * 2)
    local y = cy - MARGIN + love.math.random() * (window.height + MARGIN * 2 + START_HEIGHT)
    local ground = terrain:surfaceHeight(x, y)
    local h = START_HEIGHT * (spreadDown and love.math.random() or (0.8 + love.math.random() * 0.2))
    return { x = x, y = y, z = ground + h }
end

-- Fixed-timestep update.
function weather:update(dt)
    updateLightning(self, dt)
    local step = dt / FADE_TIME
    local function ease(v, target)
        if v < target then return math.min(target, v + step) end
        return math.max(target, v - step)
    end
    self.amount = ease(self.amount, self.mode == "rain" and 1 or 0)
    self.fog = ease(self.fog, self.mode == "fog" and 1 or 0)
    self.fogDrift[1] = self.fogDrift[1] + FOG_DRIFT[1] * dt
    self.fogDrift[2] = self.fogDrift[2] + FOG_DRIFT[2] * dt

    -- As many drops as the rain is heavy (new ones start anywhere in the
    -- column so the rain doesn't arrive as one sheet).
    local want = math.floor(window.width * window.height * DROPS_PER_PX * self.amount)
    while #drops < want do drops[#drops + 1] = newDrop(true) end
    while #drops > want do table.remove(drops) end

    local cx, cy = camera:get()
    local driftX = (WIND_SLANT * FALL_SPEED + clouds.windX * 2) * dt
    for i, d in ipairs(drops) do
        d.z = d.z - FALL_SPEED * dt
        d.x = d.x + driftX
        local ground = terrain:surfaceHeight(d.x, d.y)
        local surface = water:surfaceAt(math.floor(d.x / 32) + 1, math.floor(d.y / 32) + 1)
        local floor = surface or ground
        if d.z <= floor then
            if surface then splash:ring(d.x, d.y, surface, 5, 0.45)
            elseif #splats < 400 then splats[#splats + 1] = { x = d.x, y = d.y, z = ground, age = 0 } end
            drops[i] = newDrop(false)
        elseif d.x < cx - MARGIN * 2 or d.x > cx + window.width + MARGIN * 2
            or d.y < cy - MARGIN * 2 or d.y > cy + window.height + START_HEIGHT + MARGIN * 2 then
            drops[i] = newDrop(true)              -- the view moved away from it
        end
    end

    for i = #splats, 1, -1 do
        local s = splats[i]
        s.age = s.age + dt
        if s.age >= SPLAT_TIME then table.remove(splats, i) end
    end
end

-- Sun state for the current weather: a copy of `sunState` with direct light
-- cut down toward the shadow level (overcast: shadows go soft and faint).
local overcastState = {}
function weather:overcast(sunState)
    for k, v in pairs(sunState) do overcastState[k] = v end
    -- How much of the direct sun is cut: the heavier of rain and fog.
    local cut = math.max(self.amount * (1 - OVERCAST), self.fog * (1 - FOG_OVERCAST))
    if cut > 0 then
        local lit, shadow = sunState.litLevel, sunState.shadowLevel
        overcastState.litLevel = lit - (lit - shadow) * cut
    end
    return overcastState
end

-- Draws the falling rain and splats onto canvas.intermediate (the lit,
-- tinted frame). Call after lighting:composite.
function weather:draw(cameraX, cameraY)
    if #drops == 0 and #splats == 0 then return end
    batch:clear()
    local slant = WIND_SLANT + clouds.windX * 2 / FALL_SPEED
    local angle = -math.atan(slant)    -- the streak trails up and back from the drop
    local c = DROP_COLOUR
    batch:setColor(c[1], c[2], c[3], math.min(1, c[4] * math.min(1, self.amount * 1.5) * (1 + self.flash * 1.2)))   -- streaks flare in lightning
    for _, d in ipairs(drops) do
        local sx, sy = d.x - cameraX, d.y - d.z - cameraY
        -- A streak trailing up and back along the way it's falling.
        batch:add(math.floor(sx + 0.5), math.floor(sy + 0.5), angle, 1, STREAK, 0, 1)
    end
    for _, s in ipairs(splats) do
        local t = s.age / SPLAT_TIME
        local sx, sy = math.floor(s.x - cameraX + 0.5), math.floor(s.y - s.z - cameraY + 0.5)
        local spread = 1 + math.floor(t * 2)
        batch:setColor(c[1], c[2], c[3], 0.6 * (1 - t))
        batch:add(sx - spread, sy - 1)
        batch:add(sx + spread, sy - 1)
        if t < 0.5 then batch:add(sx, sy - 2) end
    end
    love.graphics.setCanvas(canvas.intermediate)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(batch)
end

return weather
