-- sun.lua
--
-- The sun drives every time-of-day effect: shadow direction and length,
-- shadow darkness, how brightly cliff faces are lit, and which colour-grading
-- LUT is used.
--
-- `sun.angle` is a single number in degrees that runs 0 -> 360 over one day:
--
--     0   sunrise (sun on the eastern horizon, +x)
--     90  noon    (sun high in the south, toward the camera, +y)
--     180 sunset  (sun on the western horizon, -x)
--     180-360     night (no sun shadows)
--
-- The angle doubles as the sun's compass direction (azimuth) in screen space:
-- (cos(angle), sin(angle)) points from the ground TOWARD the sun. Its height
-- in the sky (altitude) rises and falls with sin(angle), from `minAltitude`
-- at sunrise/sunset to `maxAltitude` at noon. Altitude decides shadow length:
-- something H px tall casts a shadow H / tan(altitude) px long. Keeping
-- minAltitude at 45 degrees (tan = 1) means a shadow is never longer than the
-- height of whatever casts it.

sun = {}

sun.angle         = 0
sun.rotationSpeed = 30                  -- degrees/second while holding M or N (debug)
sun.dayLength     = 1200                -- seconds for one full day/night cycle (20 min)
sun.maxAltitude   = math.rad(75)        -- noon: shadows ~0.27x the caster's height
sun.minAltitude   = math.rad(45)        -- sunrise/sunset: shadows exactly 1x height (never longer)

-- Shadow softness: the sun's apparent size (in radians-ish). A shadow edge
-- blurs by about `softness` px for every px it is from whatever casts it,
-- so shadows stay crisp where they touch the caster and soften with
-- distance. 0 = razor-sharp pixel edges; 0.08 = gently soft; 0.15+ = very soft.
sun.softness      = 0.02

-- LIGHT LEVELS
-- Light is split in two: AMBIENT (sky light, reaches everything) and DIRECT
-- (the sun itself, blocked by anything casting a shadow).
--   shadowed pixel = ambient
--   sunlit pixel   = ambient + direct
-- Shadows never fade out while the scene stays bright. Over the last
-- `twilightDegrees` before sunset, sunlit and shadowed levels both move
-- to `twilightLevel` and meet at sunset. Because the colour grade (LUT) is
-- darkening fast at the same time, sunlit ground gets steadily darker and
-- shadowed ground never gets brighter on screen. The shadows sink into the
-- dusk rather than turning see-through.
--
-- twilightLevel was picked by running grass through the LUT across the day:
--   * at the ambient level (0.505) sunset went nearly black, darker than night
--   * at 1.0, shadowed ground brightened 11 -> 28 (out of 100) before sunset
--   * at 0.65, sunlit falls 39 -> 23 -> 11 -> 8, shadowed holds 11 -> 9 -> 8,
--     and sunset (8) blends straight into night (9)
--
-- After sunset the level eases from twilightLevel to 1.0 over
-- `nightRecoveryDegrees` while the LUT blends dusk -> night, so nights look
-- the same as before. Dawn mirrors all of this.
sun.ambientLevel         = 0.505   -- shadowed ground at full day (sunlit = 1.0)
sun.twilightLevel        = 0.65    -- where sunlit and shadowed levels meet at sunset/sunrise
sun.twilightDegrees      = 30      -- how long before sunset (after sunrise) the sun dims
sun.nightRecoveryDegrees = 80      -- matches the LUT's dusk->night / night->dawn blend

-- Cliff-face brightness multipliers (see sun:getState). All visible faces
-- point south, so they're lit by how squarely the sun faces them: dim when
-- it's off to the east/west, full at noon. Tops are handled by the LUT alone.
sun.faceLightMin   = 0.70               -- sun on the east/west horizon (grazing the wall)
sun.faceLightMax   = 1.00               -- sun due south at noon (art unchanged)
sun.faceLightNight = 0.70               -- faces at night (same as sunset, so no jump)

-- The LUT image (img/LUD2.png) stacks four 32-row colour grades vertically.
-- These are the row each block starts on.
local LUT_NOON, LUT_DUSK, LUT_NIGHT, LUT_DAWN = 0, 32, 64, 96

-- Re-used every frame so getState doesn't allocate.
local state = {}

function sun:update(dt)
    -- Continuous day/night progression.
    self.angle = self.angle + (360 / self.dayLength) * dt

    -- Debug: scrub time of day.
    if love.keyboard.isDown('m') then
        self.angle = self.angle + self.rotationSpeed * dt
    end
    if love.keyboard.isDown('n') then
        self.angle = self.angle - self.rotationSpeed * dt
    end

    self.angle = self.angle % 360  -- Lua's % always returns 0..360 here, even for negatives
end

-- Picks the two LUT blocks to blend between and how far along the blend we are.
-- Returns rowA, rowB, t  (final colour = mix(LUT[rowA], LUT[rowB], t)).
--
--     0 -  80   dawn  -> noon
--    80 - 100   noon (hold)
--   100 - 180   noon  -> dusk
--   180 - 260   dusk  -> night
--   260 - 280   night (hold)
--   280 - 360   night -> dawn
function sun:getLutBlend(a)
    if a <= 80 then
        return LUT_DAWN, LUT_NOON, a / 80
    elseif a <= 100 then
        return LUT_NOON, LUT_NOON, 0
    elseif a <= 180 then
        return LUT_NOON, LUT_DUSK, (a - 100) / 80
    elseif a <= 260 then
        return LUT_DUSK, LUT_NIGHT, (a - 180) / 80
    elseif a <= 280 then
        return LUT_NIGHT, LUT_NIGHT, 0
    else
        return LUT_NIGHT, LUT_DAWN, (a - 280) / 80
    end
end

-- Everything the renderer needs to know about the sun this frame.
--
--   isUp            true between sunrise and sunset
--   dirX, dirY      unit vector on the ground plane pointing toward the sun
--   slope           tan(altitude): how many pixels a sun ray climbs per pixel
--                   travelled across the ground
--   softness        see sun.softness
--   litLevel        brightness multiplier for sunlit pixels (ambient + direct)
--   shadowLevel     brightness multiplier for shadowed pixels (ambient only)
--                   litLevel == shadowLevel means there's no direct sun, so
--                   shadows don't need computing at all.
--   faceLight       brightness multiplier for south-facing cliff faces
--   lutRowA/B, lutMix   colour-grade blend (see getLutBlend)

-- 0 -> 1 with an S-curve (eases in and out) as x goes from 0 to 1.
local function smoothstep(x)
    x = math.max(0, math.min(1, x))
    return x * x * (3 - 2 * x)
end

function sun:getState()
    local a = self.angle % 360
    local rad = math.rad(a)

    state.isUp = a > 0 and a < 180
    state.dirX, state.dirY = math.cos(rad), math.sin(rad)

    local altitude = self.minAltitude
        + (self.maxAltitude - self.minAltitude) * math.max(0, math.sin(rad))
    state.slope = math.tan(altitude)
    state.softness = self.softness

    if state.isUp then
        -- day = 0 at the horizon, 1 once the sun is twilightDegrees up.
        -- Lit and shadowed levels move from their full-day values (1.0 and
        -- ambientLevel) to meet at twilightLevel as day -> 0.
        local degreesFromHorizon = math.min(a, 180 - a)
        local day = smoothstep(degreesFromHorizon / self.twilightDegrees)
        local tw = self.twilightLevel
        state.litLevel    = tw + (1 - tw) * day
        state.shadowLevel = tw + (self.ambientLevel - tw) * day

        -- dirY = sin(azimuth): 0 when the sun is due east/west, 1 when it's
        -- due south, i.e. how directly it faces a south-pointing wall.
        local facing = math.max(0, state.dirY)
        state.faceLight = self.faceLightMin + (self.faceLightMax - self.faceLightMin) * facing
    else
        -- Night: no direct light. Ease from twilightLevel back to 1.0 as the
        -- LUT takes over the darkening (and back down before sunrise).
        local degreesFromHorizon = math.min(a - 180, 360 - a)
        local recovery = smoothstep(degreesFromHorizon / self.nightRecoveryDegrees)
        local level = self.twilightLevel + (1 - self.twilightLevel) * recovery
        state.shadowLevel, state.litLevel = level, level
        state.faceLight = self.faceLightNight
    end

    state.lutRowA, state.lutRowB, state.lutMix = self:getLutBlend(a)
    return state
end
