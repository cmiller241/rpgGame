-- ambient.lua
--
-- The little touches of life, in one place for main.lua:
--   dust.lua          dust kicked up from the player's feet
--   splash.lua        ripples and splashes when he's in water
--   fireflies.lua     fireflies blinking at night
--
-- All but the fireflies are sprites sorted with everything else per row;
-- fireflies (like the motes around the Bible pages) glow, so they're drawn
-- after the lighting pass.

local ambient = {}
package.loaded[...] = ambient  -- register now, so modules that require each other share this table

local dust = require("src.dust")
local fireflies = require("src.fireflies")
local splash = require("src.splash")

local SPRITES = { dust, splash }

-- Fixed-timestep update.
function ambient:update(dt)
    for _, m in ipairs(SPRITES) do m:update(dt) end
    fireflies:update(dt)
end

-- Adds everything in tile row `row` to that row's draw list.
function ambient:addSprites(list, row, cameraX, cameraY)
    for _, m in ipairs(SPRITES) do m:addSprites(list, row, cameraX, cameraY) end
end

-- Things that glow: drawn onto the lit frame (call after lighting:composite).
function ambient:drawGlow(cameraX, cameraY)
    fireflies:draw(cameraX, cameraY)
end

return ambient
