-- tree.lua
--
-- Trees (tile type 512). Each tree is drawn straight onto the object canvas
-- with the wind-sway shader, and queues its shadow with spriteShadow.

tree = {}

-- Where the trunk meets the ground inside the 480x480 tree quad, and the
-- point in the quad that lines up with the tile's top-left corner.
local ANCHOR_X, ANCHOR_Y = 240, 250
local ORIGIN_X, ORIGIN_Y = 224, 224
-- Height (px above the base) used to decide if a tree is in a cliff's
-- shadow: about the middle of the canopy.
local TINT_SAMPLE_HEIGHT = 110

function tree:draw(xC, yC, z, screenX, screenY)
    local ts = sprites.size
    local quadX, quadY, quadW, quadH = sprites.treeTrunk:getViewport()
    local texW, texH = sprites.tree:getDimensions()

    -- World position of the trunk base.
    local baseX = (xC - 1) * ts + (ANCHOR_X - ORIGIN_X)
    local baseY = (yC - 1) * ts + (ANCHOR_Y - ORIGIN_Y)
    local baseZ = -z

    -- The sway shader needs to know which part of the atlas is this sprite,
    -- so it can keep the trunk still and bend only the canopy.
    local s = shader.windSway
    love.graphics.setCanvas(canvas.object)
    love.graphics.setShader(s)
    s:send("time", love.timer.getTime())
    s:send("windStrength", 5.0 / texW)           -- ~5 px max shift at the treetop
    s:send("windSpeed", 3.0)
    s:send("phase", xC * 1.7 + yC * 0.6)         -- de-sync neighbouring trees
    s:send("quadV0", quadY / texH)
    s:send("quadV1", (quadY + quadH) / texH)
    s:send("anchorV", 0.55)                      -- 0 = top of quad, 1 = bottom; trunk base ~0.52

    local tint = lighting:objectTint(baseX, baseY, baseZ + TINT_SAMPLE_HEIGHT)
    love.graphics.setColor(tint, tint, tint, 1)
    love.graphics.draw(sprites.tree, sprites.treeTrunk, screenX, screenY + z, 0, 1, 1, ORIGIN_X, ORIGIN_Y)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setShader()

    -- Shadow doesn't sway (it uses the un-sheared sprite).
    spriteShadow:add{
        image = sprites.tree,
        quadX = quadX, quadY = quadY, quadW = quadW, quadH = quadH,
        anchorX = ANCHOR_X, anchorY = ANCHOR_Y,
        worldX = baseX, worldY = baseY, worldZ = baseZ,
        castLamp = true,
    }
end
