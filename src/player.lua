-- player.lua
--
-- The player character: movement, jumping, tool use (hoe, seeds, watering
-- can), picking up Bible pages, and drawing.
--
-- Position: player.x / player.y are world pixels. player.y is where his feet
-- are; the collision box spans x .. x+32 and y-8 .. y.
-- Height uses the map's convention: player.z is NEGATIVE going up (0 =
-- ground level, -32 = one tile up). player.shadowZ is the z of the ground
-- under him, so (shadowZ - z) is how high he is jumping.

local player = {}
package.loaded[...] = player  -- register now, so modules that require each other share this table

local canvas = require("src.canvas")
local mapArray = require("src.level").cells
local message = require("src.message")
local object = require("src.objects")
local sounds = require("src.sounds")
local spriteMap = require("spritemap")
local spriteShadow = require("src.spriteShadow")
local sprites = require("src.sprites")
local terrain = require("src.terrain")
local water = require("src.water")
local tiles = require("src.tiles")
local toolbarMap = require("src.toolbarMap")
local ui = require("src.ui")

player.spriteSheet = love.graphics.newImage("img/sprites-fixedgrid.png")
player.quads = {}
do
    local w, h = player.spriteSheet:getDimensions()
    local cols = math.ceil(w / 112)
    local rows = math.ceil(h / 112)
    for i = 1, rows do
        for j = 1, cols do
            table.insert(player.quads, love.graphics.newQuad((j-1)*112, (i-1)*112, 112, 112, w, h))
        end
    end
end

-- Initial properties
player.x, player.y, player.z, player.shadowZ = 100, 250, 0, 0
player.ax, player.ay, player.az = 0, 0, 0   -- acceleration this tick (from input)
player.vx, player.vy, player.vz = 0, 0, 0   -- velocity (vz < 0 = rising)
player.friction, player.speed, player.zSpeed, player.speedLimit = 0.99, 10, 0.5, 4
player.jump = false
player.jumpForce = -13
player.gravity = 0.1
player.gravityFactor = 250
player.speedCharacter = 10
player.isOnGround = true
player.direction = "Down"
player.state = "Standing"
player.frame = 1
player.frameTime = 0
player.frameDuration = 0.2
player.facingPage = nil      -- Bible page he could pick up right now (set in update)
player.screenItem = nil      -- his draw item this frame (set in addSprites)
player.screenBox = nil       -- his body's screen rectangle this frame (set in addSprites)

-- Tool animation tracking
player.animations = {
    Plowing = { time = 0, done = false, tileType = 56, frameTrigger = 4, canFunc = "canPlow" },
    Sowing  = { time = 0, done = false, tileType = 72, frameTrigger = -1, canFunc = "canSow" },
    Watering = { time = 0, done = false, tileType = 73, frameTrigger = 3, canFunc = "canWater" },
    PickUp = { time = 0, done = false, frameTrigger = 3, canFunc = "canPickUp" }
}


-- Collision box, relative to (player.x, player.y). 24 px wide to match his
-- body (his side-on body is 23 px wide), centred on x + 16 like the sprite.
-- 8 px tall at his feet.
local BOX_LEFT, BOX_RIGHT = 4, 27
local BOX_TOP, BOX_BOTTOM = -8, 0
-- How tall he is (px, feet to top of hair), for floating blocks: he can walk
-- under a block only if its underside is at least this far above his feet.
local PLAYER_HEIGHT = 60

-- Column of the 112 px side-facing (Left/Right) frames where his body is
-- centred (body spans columns 41-63). See player:draw.
local SIDE_BODY_CENTRE = 52

-- The tile (col, row) directly in front of the player, i.e. the one his
-- tools act on.
function player:getTargetTile()
    local playerTileX = math.floor((self.x + 16) / sprites.size) + 1
    local playerTileY = math.floor(self.y / sprites.size) + 1
    local dx, dy = 0, 0
    if self.direction == "Left" then dx = -1
    elseif self.direction == "Right" then dx = 1
    elseif self.direction == "Up" then dy = -1
    elseif self.direction == "Down" then dy = 1 end
    return playerTileX + dx, playerTileY + dy
end

-- Called each time a tool animation advances a frame. On the animation's
-- trigger frame (e.g. the hoe hitting the ground) it changes the target tile
-- once: plow grass -> dirt, sow dirt -> seeds, or water dry -> wet.
function player:handleToolAnimation(state, frame, numFrames)
    local anim = self.animations[state]
    if not anim then return end
    local trigger = anim.frameTrigger == -1 and (numFrames - 1) or anim.frameTrigger
    if self.frame == trigger and not anim.done then
        if state ~= "PickUp" then
            local tx, ty = self:getTargetTile()
            if self[anim.canFunc](self, tx, ty) then
                if state == "Watering" then
                    -- Watering advances dry (even) tile to wet (odd)
                    mapArray[ty][tx][1] = mapArray[ty][tx][1] + 1
                else
                    -- Plowing/Sowing use fixed tileType
                    mapArray[ty][tx][1] = anim.tileType
                end
                anim.done = true
            end
        else
            anim.done = true
        end
    end
end

-- Ends a tool animation and returns to standing. Finishing a pickup opens
-- the message box with the page's verse.
function player:resetToolState(state)
    local anim = self.animations[state]
    if anim then
        anim.time = 0
        anim.done = false
        if state ~= "PickUp" then
            self.state = "Standing"
            self.frame = 1
            self.frameTime = 0
        else
            message:show()
        end
    end
end

-- Fixed-timestep update: animation frames, tool animations, arrow-key
-- movement, jumping and gravity.
function player:update(dt)
    if message.isActive then return end
    self.facingPage = object:findFacing(self)    -- drives the outline and the F key
    local prevState, prevDir = self.state, self.direction
    local isToolState = self.animations[self.state]
    local frameDuration = spriteMap.Cody[self.state][self.direction].frames[self.frame].duration or 5.0
    self.frameTime = self.frameTime + dt

    if self.frameTime >= frameDuration then
        self.frame = self.frame + 1
        self.frameTime = 0

        local numFrames = #spriteMap.Cody[self.state][self.direction].frames
        if self.frame > numFrames then
            if isToolState then
                self:resetToolState(self.state)
            else
                self.frame = 1
            end
        else
            self:handleToolAnimation(self.state, self.frame, numFrames)
        end
    end

    if isToolState then
        local anim = self.animations[self.state]
        if anim then
            -- Calculate total animation duration
            local totalDuration = 0
            for _, frame in ipairs(spriteMap.Cody[self.state][self.direction].frames) do
                totalDuration = totalDuration + frame.duration
            end
            anim.time = anim.time + dt
            if anim.time >= totalDuration then
                self:resetToolState(self.state)
            end
        end
        return
    end

    -- Movement input
    self.ax, self.ay = 0, 0
    local moving = false
    for _, info in ipairs({
        { "right", 1, 0, "Right" },
        { "left", -1, 0, "Left" },
        { "up", 0, -1, "Up" },
        { "down", 0, 1, "Down" }
    }) do
        if love.keyboard.isDown(info[1]) then
            self.ax = info[2] * self.speed * dt
            self.ay = info[3] * self.speed * dt
            self.direction = info[4]
            moving = true
        end
    end

    self.state = moving and "Walking" or "Standing"
    if not moving then self.vx, self.vy = 0, 0 end

    -- Jumping
    if not self.isOnGround then
        self.state = self.vz < 0 and "Jumping-Up" or "Jumping-Down"
    end
    if self.jump and self.isOnGround then
        self.vz = self.jumpForce
        self.jump = false
        self.isOnGround = false
    end

    -- Gravity. (The ground stops him in moveCharacter, at whatever height
    -- the tile under him is, including the floor of a pit.)
    self.vz = self.vz + self.gravity * self.gravityFactor * dt

    self.vx = (self.vx + self.ax) * self.friction
    self.vy = (self.vy + self.ay) * self.friction
    self.vx = math.max(-self.speedLimit, math.min(self.vx, self.speedLimit))
    self.vy = math.max(-self.speedLimit, math.min(self.vy, self.speedLimit))

    local beforeX, beforeY = self.x, self.y
    self:moveCharacter(self.vx, self.vy, self.vz * 20 * dt)

    -- Pushing against a wall: stand still instead of walking on the spot
    -- (the walking stride would poke his foot into the wall). The 1 px
    -- check also ignores ticks where velocity is still too small to move.
    if self.state == "Walking" and self.x == beforeX and self.y == beforeY
       and not self:canMoveTo(self.x + (self.ax > 0 and 1 or self.ax < 0 and -1 or 0),
                              self.y + (self.ay > 0 and 1 or self.ay < 0 and -1 or 0), self.z) then
        self.state = "Standing"
    end

    if self.state ~= prevState or self.direction ~= prevDir then
        self.frame = 1
        self.frameTime = 0
    end
end

-- Space starts a jump wind-up; F uses the selected tool, or picks up a
-- Bible page if one is highlighted in front of the player.
function player:keypressed(key)
    if key == "space" and self.isOnGround then
        self.state = "Jumping-Start"
        self.direction = "Down"
        self.frame = 1
    elseif key == "f" then
        local page = object:findFacing(self)
        if page then
            -- Pick up the Bible page in front of him and queue its message.
            message.text = page.message
            message.verse = page.verse
            message.tool = page.tool
            message.toolMessage = page.toolMessage or ""
            object:remove(page)
            self.state = "PickUp"
            self.frame, self.frameTime = 1, 0
            local anim = self.animations["PickUp"]
            anim.time = 0
            anim.done = false
            sounds.play("sow")
        else
            local tool = self:selectedTool()
            local tx, ty = self:getTargetTile()

            local function triggerTool(state, canFunc, sound)
                if self[canFunc](self, tx, ty) then
                    self.state = state
                    self.frame, self.frameTime = 1, 0
                    local anim = self.animations[state]
                    anim.time = 0
                    anim.done = false
                    sounds.play(sound)
                end
            end

            if tool == "Hoe" then
                triggerTool("Plowing", "canPlow", "shovel")
            elseif tool == "Watering Can" then
                triggerTool("Watering", "canWater", "water")
            elseif tool:find("Seed") then
                triggerTool("Sowing", "canSow", "sow")
            end
        end
    elseif key == "w" then
        -- Cast a layer of water onto the outlined tile (Hoe selected).
        if self:selectedTool() == "Hoe" then
            local tx, ty = self:getTargetTile()
            water:add(tx, ty, water.castAmount)
            sounds.play("water")
        end
    elseif key == "e" then
        -- Place / remove a floating block over the outlined tile (Hoe selected).
        if self:selectedTool() == "Hoe" then self:toggleBlock() end
    elseif key == "q" then
        -- Shape the land with the Hoe: Q raises, Shift+Q lowers. With Ctrl,
        -- in small steps that make slopes instead of cliffs.
        local lower = love.keyboard.isDown("lshift", "rshift")
        local fine = love.keyboard.isDown("lctrl", "rctrl")
        self:shapeTerrain(lower and -1 or 1, fine)
    end
end

-- Releasing space launches the jump (applied in player:update).
function player:keyreleased(key)
    if key == "space" and not self.jump and self.isOnGround then
        self.jump = true
    end
end

-- Applies one tick of movement. Each axis (x, then y, then z) moves on its
-- own, one pixel at a time, and stops at the last free pixel. So:
--   * walking into a cliff, tree or block puts him flush against it, no gap;
--   * if one axis is blocked the others still move (he slides along walls);
--   * landing on a ledge or block puts his feet exactly on top of it;
--   * jumping into the underside of a floating block stops him there and
--     he falls back down (z is negative-up, so a smaller target is "up").
function player:moveCharacter(dx, dy, dz)
    if self:moveAxis("x", math.floor(self.x + dx + 0.5)) then self.vx = 0 end
    if self:moveAxis("y", math.floor(self.y + dy + 0.5)) then self.vy = 0 end
    local oldZ = self.z
    local targetZ = math.floor(self.z + dz + 0.5)
    if self:moveAxis("z", targetZ) then
        self.vz = 0
        if targetZ > oldZ then
            self.isOnGround = true        -- moving down and stopped: landed (or already standing)
        end                               -- moving up and stopped: bumped his head
    elseif self.z > oldZ then
        self.isOnGround = false           -- dropping: walked off a ledge or into a pit
    end

    self:updateGround()
end

-- Height of whatever he's standing on: the highest ground or floating-block
-- top under any part of his collision box that's at or below his feet
-- (matching canMoveTo, so standing on the edge of a block counts). Used for
-- his shadow, jump height and pit focus.
function player:supportHeight(x, y, z)
    local ts = sprites.size
    local feet = -z
    local best = -math.huge
    for row = math.floor((y + BOX_TOP) / ts) + 1, math.floor((y + BOX_BOTTOM) / ts) + 1 do
        for col = math.floor((x + BOX_LEFT) / ts) + 1, math.floor((x + BOX_RIGHT) / ts) + 1 do
            best = math.max(best, terrain:supportAt(col, row, feet,
                x + BOX_LEFT, y + BOX_TOP, x + BOX_RIGHT + 1, y + BOX_BOTTOM + 1))
        end
    end
    return best
end

function player:updateGround()
    self.shadowZ = -self:supportHeight(self.x, self.y, self.z)
end

-- Steps self[axis] toward `target` one pixel at a time until it arrives or
-- the next pixel would collide. Returns true if it was blocked. Moves are at
-- most a few pixels per tick, so this is only a handful of checks.
--
-- SLOPES (terrain.lua): walking (x / y) while on the ground follows the
-- ground up and down a slope. A slope rises less than 1 px per px walked, so
-- if the next pixel is blocked only by ground at most SLOPE_STEP px higher,
-- he steps up onto it; and if the ground under him has dropped by at most
-- SLOPE_STEP, he steps down with it instead of falling. Cliffs are at least
-- 32 px, so they still block (or let him fall) as before.
local SLOPE_STEP = 2

function player:moveAxis(axis, target)
    local step = (target > self[axis]) and 1 or -1
    local walking = axis ~= "z" and self.isOnGround
    while self[axis] ~= target do
        local x, y, z = self.x, self.y, self.z
        if axis == "x" then x = x + step
        elseif axis == "y" then y = y + step
        else z = z + step end

        if not self:canMoveTo(x, y, z) then
            -- Up a slope?
            local climbed = false
            if walking then
                local ground = self:supportHeight(x, y, -100000)   -- highest ground under him there
                local rise = ground - (-z)
                local newZ = -math.ceil(ground - 1e-6)
                if rise > 0 and rise <= SLOPE_STEP and self:canMoveTo(x, y, newZ) then
                    self.z = newZ
                    climbed = true
                end
            end
            if not climbed then return true end
        end
        self[axis] = self[axis] + step

        -- Down a slope?
        if walking then
            local ground = self:supportHeight(self.x, self.y, self.z)
            local drop = -self.z - ground
            if drop > 1e-6 and drop <= SLOPE_STEP then
                self.z = -math.ceil(ground - 1e-6)
            end
        end
    end
    return false
end

-- Can the player's collision box be at (newX, newY) at height newZ? Blocked
-- by the solid part of a tile (e.g. a tree trunk, see tiles.lua), by any
-- tile taller than newZ, by a floating block his body would overlap, and by
-- the edge of the map.
--
-- See BOX_LEFT etc. and PLAYER_HEIGHT at the top of this file for his size.
function player:canMoveTo(newX, newY, newZ)
    local left = newX + BOX_LEFT
    local right = newX + BOX_RIGHT
    local top = newY + BOX_TOP
    local bottom = newY + BOX_BOTTOM
    local feet = -newZ
    local ts = sprites.size

    -- Every tile the box overlaps (at most 2x2).
    for row = math.floor(top / ts) + 1, math.floor(bottom / ts) + 1 do
        for col = math.floor(left / ts) + 1, math.floor(right / ts) + 1 do
            local cell = mapArray[row] and mapArray[row][col]
            if not cell then return false end                       -- off the map
            -- Ground (following slopes) higher than his feet anywhere under him.
            if terrain:groundMaxIn(col, row, left, top, right + 1, bottom + 1) > feet + 1e-6 then
                return false
            end
            if tiles.blocks(col, row, left, top, right, bottom) then return false end
            -- Floating block: solid from its underside b to its top; his body
            -- runs from his feet to feet + PLAYER_HEIGHT.
            local b = terrain:blockAt(col, row)
            if b and feet < b + terrain.blockSize and feet + PLAYER_HEIGHT > b then
                return false
            end
        end
    end
    return true
end

-- Tile type (v) and z at a world position. Off the map counts as an
-- impassable wall (v = 9999) so the player can't walk off the edge (which
-- used to crash with a nil index).
function player:getTile(x, y)
    local tileX = math.floor(x / 32) + 1
    local tileY = math.floor(y / 32) + 1
    local cell = mapArray[tileY] and mapArray[tileY][tileX]
    if not cell then
        return { v = 9999, z = 0 }
    end
    return { v = cell[1], z = cell[2] }
end

-- Is tile (tx, ty) at the player's own height? On a flat tile his feet must
-- be exactly at its height; on a slope, anywhere within the tile's range of
-- heights (he stands at the whole pixel just above the ground).
function player:atLevelOf(tx, ty)
    local k = terrain:cornersOf(tx, ty)
    local feet = -self.z
    if k.flat then return feet == k[1] end
    local lo = math.min(k[1], k[2], k[3], k[4], k[5])
    local hi = math.max(k[1], k[2], k[3], k[4], k[5])
    return feet >= lo - 0.5 and feet < hi + 1
end

-- Tool checks: each tool only works on the right tile type at the player's
-- own height.
function player:canPlow(tx, ty)
    if mapArray[ty] and mapArray[ty][tx] then
        local tile = mapArray[ty][tx]
        return tile[1] == 1 and self:atLevelOf(tx, ty)
    end
    return false
end

function player:canSow(tx, ty)
    if mapArray[ty] and mapArray[ty][tx] then
        local tile = mapArray[ty][tx]
        return tile[1] == 56 and self:atLevelOf(tx, ty)
    end
    return false
end

function player:canWater(tx, ty)
    if mapArray[ty] and mapArray[ty][tx] then
        return tiles.isDryCrop(mapArray[ty][tx][1]) and self:atLevelOf(tx, ty)
    end
    return false
end

-- Is a Bible page within reach and in the direction the player is facing?
function player:canPickUp()
    return object:findFacing(self) ~= nil
end

-- SMOOTH DRAWING
-- Movement runs at a fixed 60 ticks/second, but the screen may refresh
-- faster. Drawing his exact tick position would hold him still for a few
-- frames and then jump. Instead we remember where he was at the start of
-- the tick and draw him part-way between that and where he is now.
player.prevX, player.prevY, player.prevZ = player.x, player.y, player.z
player.drawX, player.drawY, player.drawZ = player.x, player.y, player.z

-- Moves him instantly (no smoothing between old and new spot).
function player:teleport(x, y, z)
    self.x, self.y, self.z = x, y, z or 0
    self:updateGround()
    self.vx, self.vy, self.vz = 0, 0, 0
    self:rememberPosition()
    self:updateDrawPosition(1)
end

-- Call at the start of every fixed update tick, before he moves.
function player:rememberPosition()
    self.prevX, self.prevY, self.prevZ = self.x, self.y, self.z
end

-- alpha = how far we are into the next tick (0..1). Rounded to whole pixels
-- so the pixel art stays crisp.
function player:updateDrawPosition(alpha)
    local function lerp(a, b) return math.floor(a + (b - a) * alpha + 0.5) end
    self.drawX = lerp(self.prevX, self.x)
    self.drawY = lerp(self.prevY, self.y)
    self.drawZ = lerp(self.prevZ, self.z)
end

-- Called while building the scene (see main.lua). Renders his current frame
-- into canvas.temp, queues his shadow, and adds a draw item.
function player:addSprites(list, cameraX, cameraY)
    local flipX = self.direction == "Left" and -1 or 1
    local spriteNumber = spriteMap.Cody[self.state][self.direction].frames[self.frame].sprite

    -- The current frame is first drawn into a 200x200 scratch canvas
    -- (canvas.temp), which is then used both to draw the player and as the
    -- silhouette for his shadow. Column 100 of canvas.temp lines up with the
    -- middle of his collision box (world x + 16).
    --
    -- In the side-facing (Left/Right) frames his body isn't centred in the
    -- 112 px frame: it spans columns 41-63, centre 52. So those frames are
    -- placed with column 52 on canvas column 100, and "Left" mirrors around that
    -- same column. That keeps his body inside his collision box facing either
    -- way, with no jump when he turns. Up/Down frames are already centred
    -- (column ~56).
    local bodyCentre = (self.direction == "Left" or self.direction == "Right") and SIDE_BODY_CENTRE or 56
    love.graphics.setCanvas(canvas.temp)
    -- Origin at the body centre, so flipping mirrors around it.
    love.graphics.draw(self.spriteSheet, self.quads[spriteNumber], 100, 100 - 56, 0, flipX, 1, bodyCentre, 0)

    -- In canvas.temp the feet are at row 124, centred on column 100.
    local x, y, z = self.drawX, self.drawY, self.drawZ
    local jumpHeight = math.max(0, self.shadowZ - z)  -- px above the ground (z is negative-up)

    -- No `data` field: his silhouette only exists on the GPU (canvas.temp),
    -- so he casts shadows on the ground but not onto other sprites.
    local caster = {
        image = canvas.temp,
        quadX = 0, quadY = 0, quadW = 200, quadH = 200,
        anchorX = 100, anchorY = 124,
        worldX = x + 16, worldY = y - 4, worldZ = -self.shadowZ,
        lift = jumpHeight,
        opacity = 1 - jumpHeight / 320,          -- shadow fades the higher he jumps
    }
    spriteShadow:add(caster)

    local item = {
        owner = self, caster = caster,
        sortY = y - cameraY, sortX = x - cameraX,
        screenX = x - cameraX, screenY = y - cameraY, z = z,
        tintX = x + 16, tintY = y - 4, tintZ = -z + 24,
    }
    -- Standing on (or above) a floating block under his box: draw him after
    -- the row's blocks so he's on top of it, not hidden by it (main.lua).
    local ts = sprites.size
    item.drawLast = false
    for row = math.floor((y + BOX_TOP) / ts) + 1, math.floor((y + BOX_BOTTOM) / ts) + 1 do
        for col = math.floor((x + BOX_LEFT) / ts) + 1, math.floor((x + BOX_RIGHT) / ts) + 1 do
            local b = terrain:blockAt(col, row)
            if b and -z >= b + terrain.blockSize - 0.5 then item.drawLast = true end
        end
    end
    list[#list + 1] = item

    -- Rough screen rectangle of his body (about 28 px wide, 80 tall above
    -- his feet). Trees in front of him that overlap it fade out (tree.lua).
    self.screenItem = item
    self.screenBox = {
        x0 = item.screenX + 2,  x1 = item.screenX + 30,
        y0 = item.screenY + z - 80, y1 = item.screenY + z,
    }
end

-- Draws the player (from canvas.temp) onto canvas.object, plus the Bible page
-- he's holding during a pickup.
function player:drawItem(item, tint)
    local characterScreenX, characterScreenY = item.screenX, item.screenY
    local flipX = self.direction == "Left" and -1 or 1
    local flipOffsetX = 0   -- the pickup overlay below always faces Down

    love.graphics.setColor(tint, tint, tint, 1)
    -- His full sprite on the x-ray canvas, which nothing ever covers. Where
    -- terrain in front hides him on canvas.object, the lighting pass shows
    -- this as a ghost instead (see ultimateShader.glsl).
    love.graphics.setCanvas(canvas.xray)
    love.graphics.draw(canvas.temp, characterScreenX + 16 - 100, characterScreenY - 128 + item.z)
    love.graphics.setCanvas(canvas.object)
    love.graphics.draw(canvas.temp, characterScreenX + 16 - 100, characterScreenY - 128 + item.z)

    -- Draw Bible page in player's hands during PickUp animation or when message is active
    if self.state == "PickUp" or message.isActive then
        self.direction = "Down"
        local pageOffsetX, pageOffsetY = 0, 0
        local anim = self.animations["PickUp"]
        if self.state == "PickUp" and not message.isActive then
            if self.frame == 1 then
                pageOffsetX = flipX * 1 -- Slightly forward, near feet
                pageOffsetY = 30 -- Near ground
            elseif self.frame == 2 then
                pageOffsetX = flipX * 1 -- Near chest
                pageOffsetY = 10 -- Chest level
            elseif self.frame == 3 then
                pageOffsetX = flipX * 1 -- Centered above head
                local frameStartTime = 0.125 + 0.125 -- Time when frame 3 starts
                local t = math.min((anim.time - frameStartTime) / 1.0, 1.0) -- Normalized time (0 to 1)
                pageOffsetY = -40 + t * (-60 - (-40)) -- Linear interpolation from -40 to -60
            end
        else
            -- Message is active, draw Bible page at final position
            pageOffsetX = flipX * 1
            pageOffsetY = -60
        end
        love.graphics.draw(
            sprites.objects,
            sprites.biblePageCenter,
            characterScreenX + 16 - 32 + pageOffsetX,
            characterScreenY - 64 + item.z + pageOffsetY,
            0,
            1,
            1,
            0,
            0
        )
        if self.frame == 2 and self.direction == "Down" then
            love.graphics.draw(self.spriteSheet, self.quads[97], characterScreenX + 16 - 55, characterScreenY - 84 + item.z, 0, flipX, 1, flipOffsetX, 0)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Name of the tool in the highlighted toolbar slot (e.g. "Hoe", "Empty").
function player:selectedTool()
    return toolbarMap.slots[toolbarMap.visibleSlots[ui.highlightedSlot]].name
end

-- FLOATING BLOCKS (E with the Hoe selected)
-- Places a block over the outlined tile, BLOCK_GAP px above its ground, or
-- removes the block that's there. Refused if it would trap the player.
-- His jump peaks at ~65 px, so with a 24 px gap the block's top (56 px) is
-- comfortably reachable. To walk UNDER a block its underside must be at least
-- PLAYER_HEIGHT (60 px) up; such blocks can only be reached from higher ground.
local BLOCK_GAP = 24

function player:toggleBlock()
    local tx, ty = self:getTargetTile()
    if not (mapArray[ty] and mapArray[ty][tx]) then return end
    if terrain:blockAt(tx, ty) then
        terrain:setBlock(tx, ty, nil)
    else
        terrain:setBlock(tx, ty, terrain:heightAtTile(tx, ty) + BLOCK_GAP)
        if not self:canMoveTo(self.x, self.y, self.z) then
            terrain:setBlock(tx, ty, nil)              -- would trap him: undo
            return
        end
    end
    sounds.play("shovel")
end

-- TERRAIN SHAPING (Q / Shift+Q with the Hoe selected)
-- Raises (direction = 1) or lowers (direction = -1) the tile in front of the
-- player by one level. Heights stay between -MAX_DEPTH (a pit) and MAX_RAISE.
-- Refused if the new height would put the player inside the tile (his
-- collision box can overlap the target tile when he faces sideways).
local RAISE_STEP = 32                 -- one tile
local FINE_STEP  = 8                  -- Ctrl+Q: small enough to make a slope
local MAX_RAISE  = 10 * RAISE_STEP    -- tallest a player-made mountain can get
local MAX_DEPTH  = 5 * RAISE_STEP     -- deepest a pit can get (deeper only shows more back wall)

function player:shapeTerrain(direction, fine)
    if self:selectedTool() ~= "Hoe" then return end
    local tx, ty = self:getTargetTile()
    local cell = mapArray[ty] and mapArray[ty][tx]
    if not cell then return end

    local oldHeight = -cell[2]
    local step = fine and FINE_STEP or RAISE_STEP
    local newHeight = math.max(-MAX_DEPTH, math.min(MAX_RAISE, oldHeight + direction * step))
    if newHeight == oldHeight then return end
    -- Ground can't rise into a floating block above it.
    local block = terrain:blockAt(tx, ty)
    if block and newHeight > block then return end

    terrain:setTileHeight(tx, ty, newHeight)
    if not self:canMoveTo(self.x, self.y, self.z) then
        -- A small raise can join the tile to the one he's on, tilting the
        -- ground under his feet up a little (a slope): lift him onto it.
        -- Anything more would trap him: undo.
        local ground = self:supportHeight(self.x, self.y, -100000)
        local liftedZ = -math.ceil(ground - 1e-6)
        if ground - (-self.z) <= FINE_STEP and self:canMoveTo(self.x, self.y, liftedZ) then
            self.z = liftedZ
            self:updateGround()
        else
            terrain:setTileHeight(tx, ty, oldHeight)
            return
        end
    end
    sounds.play("shovel")
end

-- Outline on the tile in front of the player:
--   yellow  the selected tool can be used there (plow / sow / water)
--   white   Hoe selected but the tile can't be plowed: shows which tile
--           Q / Shift+Q will raise or lower
function player:drawOutline(cameraX, cameraY, mapArray)
    if self.facingPage then return end   -- the page's outline takes priority

    local tool = self:selectedTool()
    local isSeed = tool:find("Seed")
    if tool ~= "Hoe" and not isSeed and tool ~= "Watering Can" then return end

    local tx, ty = self:getTargetTile()
    local cell = mapArray[ty] and mapArray[ty][tx]
    if not cell then return end

    local usable = (tool == "Hoe" and self:canPlow(tx, ty)) or
                   (isSeed and self:canSow(tx, ty)) or
                   (tool == "Watering Can" and self:canWater(tx, ty))

    if usable then
        love.graphics.setColor(1, 1, 0, 1)
    elseif tool == "Hoe" then
        love.graphics.setColor(1, 1, 1, 0.8)
    else
        return
    end

    love.graphics.setCanvas(canvas.offscreen)
    local ts = sprites.size
    local x = (tx - 1) * ts - cameraX
    local y = (ty - 1) * ts - cameraY
    local k = terrain:cornersOf(tx, ty)
    if k.flat then
        love.graphics.rectangle("line", x, y - k[1], ts, ts)
    else
        -- On a slope the outline follows the tile's corners.
        love.graphics.polygon("line", x, y - k[1], x + ts, y - k[2], x + ts, y + ts - k[4], x, y + ts - k[3])
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return player
