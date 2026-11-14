-- clouds.lua
--
-- Shadows of clouds drifting over the land.
--
-- The clouds are a layer of noise high above the ground (clouds.height px),
-- moving with the wind. A point on the ground is shaded by whatever part of
-- the layer sits between it and the sun, so the shadows slide sideways as
-- the sun moves across the sky and stretch out when it's low, like the
-- terrain's own shadows.
--
-- The noise is a 256x256 texture that tiles seamlessly (each texel covers
-- texelSize world px), made once at load. The GPU samples it for terrain
-- pixels (cloudShadow() in shaders/ultimateShader.glsl); clouds:shadowAt does
-- the same on the CPU for sprites (see lighting:objectTint).

local clouds = {}
package.loaded[...] = clouds  -- register now, so modules that require each other share this table

clouds.size      = 256          -- noise texture size (texels)
clouds.texelSize = 8            -- world px per texel: the pattern repeats every 2048 px
clouds.height    = 400          -- px above the ground
clouds.windX, clouds.windY = 14, 5   -- px per second
clouds.coverage  = 0.58         -- noise level where shade starts (higher = fewer clouds)
clouds.softness  = 0.10         -- how gradually a cloud's edge fades in
clouds.strength  = 0.5          -- how much of the direct sun a thick cloud blocks (0..1)
clouds.maxShift  = 1500         -- px; caps how far a low sun projects the layer

-- Seamless noise: 4D simplex noise sampled on a torus (two circles), in
-- three octaves, then stretched to use the full 0..1 range.
do
    local n = clouds.size
    local data = love.image.newImageData(n, n, "r8")
    local values, lo, hi = {}, math.huge, -math.huge
    local tau = 2 * math.pi
    for y = 0, n - 1 do
        for x = 0, n - 1 do
            local ax, ay = tau * x / n, tau * y / n
            local v, amp, total = 0, 1, 0
            for octave = 1, 3 do
                local r = 0.9 * 2 ^ (octave - 1)
                v = v + amp * love.math.noise(math.cos(ax) * r + octave * 7.3, math.sin(ax) * r,
                                              math.cos(ay) * r, math.sin(ay) * r + octave * 3.1)
                total = total + amp
                amp = amp * 0.5
            end
            v = v / total
            values[y * n + x] = v
            lo, hi = math.min(lo, v), math.max(hi, v)
        end
    end
    for y = 0, n - 1 do
        for x = 0, n - 1 do
            data:setPixel(x, y, (values[y * n + x] - lo) / (hi - lo), 0, 0, 1)
        end
    end
    clouds.data = data
    clouds.map = love.graphics.newImage(data)
    clouds.map:setFilter("linear", "linear")
    clouds.map:setWrap("repeat", "repeat")
end

-- How far the wind has carried the clouds (world px) at time t.
function clouds:offset(t)
    return self.windX * t, self.windY * t
end

-- Where the line from ground point (wx, wy, h) toward the sun meets the
-- cloud layer, in world px (before wind).
function clouds:projected(wx, wy, h, sunState)
    local dist = math.min((self.height - h) / math.max(sunState.slope, 1e-3), self.maxShift)
    return wx + sunState.dirX * dist, wy + sunState.dirY * dist
end

-- Noise value 0..1 at world point (qx, qy) of the layer (bilinear, wrapping).
function clouds:sample(qx, qy)
    local n = self.size
    local tx, ty = qx / self.texelSize - 0.5, qy / self.texelSize - 0.5
    local x0, y0 = math.floor(tx), math.floor(ty)
    local fx, fy = tx - x0, ty - y0
    local function at(x, y) return (self.data:getPixel(x % n, y % n)) end
    local top = at(x0, y0) + (at(x0 + 1, y0) - at(x0, y0)) * fx
    local bottom = at(x0, y0 + 1) + (at(x0 + 1, y0 + 1) - at(x0, y0 + 1)) * fx
    return top + (bottom - top) * fy
end

-- Cloud density 0..1 for a noise value (the same curve as the shader).
function clouds:density(v)
    local t = math.max(0, math.min(1, (v - (self.coverage - self.softness)) / (2 * self.softness)))
    return t * t * (3 - 2 * t)
end

-- How much sun clouds block (0..strength) at world point (wx, wy), height h.
function clouds:shadowAt(wx, wy, h, sunState)
    if not sunState.isUp or self.strength <= 0 then return 0 end
    local qx, qy = self:projected(wx, wy, h, sunState)
    local ox, oy = self:offset(love.timer.getTime())
    return self.strength * self:density(self:sample(qx + ox, qy + oy))
end

-- Sends the cloud uniforms to a shader.
function clouds:sendUniforms(s, sendIfPresent)
    local ox, oy = self:offset(love.timer.getTime())
    sendIfPresent(s, "cloudMap", self.map)
    sendIfPresent(s, "cloudOffset", { ox, oy })
    sendIfPresent(s, "cloudTexelSize", self.texelSize)
    sendIfPresent(s, "cloudSize", self.size)
    sendIfPresent(s, "cloudHeight", self.height)
    sendIfPresent(s, "cloudCoverage", self.coverage)
    sendIfPresent(s, "cloudSoftness", self.softness)
    sendIfPresent(s, "cloudStrength", self.strength)
    sendIfPresent(s, "cloudMaxShift", self.maxShift)
end

return clouds
