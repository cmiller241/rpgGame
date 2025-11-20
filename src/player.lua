-- player.lua

player = {}

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
player.ax, player.ay, player.az = 0, 0, 0
player.vx, player.vy, player.vz = 0, 0, 0
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
player.isNearOutlinedObject = false

-- Tool animation tracking
player.animations = {
    Plowing = { time = 0, done = false, tileType = 56, frameTrigger = 4, canFunc = "canPlow" },
    Sowing  = { time = 0, done = false, tileType = 72, frameTrigger = -1, canFunc = "canSow" },
    Watering = { time = 0, done = false, tileType = 73, frameTrigger = 3, canFunc = "canWater" },
    PickUp = { time = 0, done = false, frameTrigger = 3, canFunc = "canPickUp" }
}

local toolbarMapErrorPrinted = false

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

function player:update(dt)
    if message.isActive then return end
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

    self.vz = self.vz + self.gravity * self.gravityFactor * dt
    if self.z > 0 then
        self.z = 0
        self.isOnGround = true
    end

    self.vx = (self.vx + self.ax) * self.friction
    self.vy = (self.vy + self.ay) * self.friction
    self.vx = math.max(-self.speedLimit, math.min(self.vx, self.speedLimit))
    self.vy = math.max(-self.speedLimit, math.min(self.vy, self.speedLimit))

    self:moveCharacter(self.vx, self.vy, self.vz * 20 * dt)

    if self.state ~= prevState or self.direction ~= prevDir then
        self.frame = 1
        self.frameTime = 0
    end
end

function player:keypressed(key)
    if key == "space" and self.isOnGround then
        self.state = "Jumping-Start"
        self.direction = "Down"
        self.frame = 1
    elseif key == "f" then
        if self.isNearOutlinedObject then
            if self:canPickUp() then
                -- Find the nearest object and store its message
                local nearestObj, minDistance = nil, math.huge
                for _, obj in ipairs(object.objects) do
                    local dx = self.x - obj.x
                    local dy = self.y - obj.y
                    local distance = math.sqrt(dx * dx + dy * dy)
                    local isFacing = false
                    if self.direction == "Up" and dy > 0 then
                        isFacing = true
                    elseif self.direction == "Down" and dy < 0 then
                        isFacing = true
                    elseif self.direction == "Left" and dx > 0 then
                        isFacing = true
                    elseif self.direction == "Right" and dx < 0 then
                        isFacing = true
                    end
                    if distance < 50 and isFacing and distance < minDistance then
                        minDistance = distance
                        nearestObj = obj
                    end
                end
                if nearestObj then
                    message.text = nearestObj.message
                    message.verse = nearestObj.verse
                    message.tool = nearestObj.tool
                    message.toolMessage = nearestObj.toolMessage or ""
                    object:removeNearest(self.x, self.y)
                    self.state = "PickUp"
                    self.frame, self.frameTime = 1, 0
                    local anim = self.animations["PickUp"]
                    anim.time = 0
                    anim.done = false
                    local s = (sounds.sow or sounds.shovel):clone()
                    s:setPitch(love.math.random(0.9, 1.1))
                    s:setVolume(love.math.random(0.8, 1.0))
                    s:play()
                end
            end
        elseif toolbarMap then
            local slot = toolbarMap.slots[toolbarMap.visibleSlots[ui.highlightedSlot]]
            local tool = slot.name
            local tx, ty = self:getTargetTile()

            local function triggerTool(state, canFunc, sound)
                if self[canFunc](self, tx, ty) then
                    self.state = state
                    self.frame, self.frameTime = 1, 0
                    local anim = self.animations[state]
                    anim.time = 0
                    anim.done = false
                    local s = (sounds[sound] or sounds.shovel):clone()
                    s:setPitch(love.math.random(0.9, 1.1))
                    s:setVolume(love.math.random(0.8, 1.0))
                    s:play()
                end
            end

            if tool == "Hoe" then
                triggerTool("Plowing", "canPlow", "shovel")
            elseif tool == "Watering Can" then
                triggerTool("Watering", "canWater", "water")
            elseif tool:find("Seed") then
                triggerTool("Sowing", "canSow", "sow")
            end
        else
            if not toolbarMapErrorPrinted then
                print("Error: toolbarMap is nil in player:keypressed")
                toolbarMapErrorPrinted = true
            end
        end
    end
end

function player:keyreleased(key)
    if key == "space" and not self.jump and self.isOnGround then
        self.jump = true
    end
end

function player:moveCharacter(dx, dy, dz)
    local newx = math.floor(self.x + dx + 0.5)
    local newy = math.floor(self.y + dy + 0.5)
    local newz = math.floor(self.z + dz + 0.5)

    local canMoveXY = self:canMoveTo(newx, newy, self.z)
    local canMoveZ = self:canMoveTo(self.x, self.y, newz)

    if canMoveXY then
        self.x = newx
        self.y = newy
    else
        self.vx = 0
        self.vy = 0
    end

    if canMoveZ then
        self.z = newz
    else
        self.vz = 0
        self.isOnGround = true
    end
end

function player:canMoveTo(newX, newY, newZ)
    local left = newX 
    local right = newX + 32
    local top = newY - 8
    local bottom = newY

    local topLeftTile = self:getTile(left, top)
    local topRightTile = self:getTile(right, top)
    local bottomLeftTile = self:getTile(left, bottom)
    local bottomRightTile = self:getTile(right, bottom)

    self.shadowZ = bottomLeftTile.z

    if (topLeftTile.v > 500 or topRightTile.v > 500 or 
        bottomLeftTile.v > 500 or bottomRightTile.v > 500 or
        topLeftTile.z < newZ or topRightTile.z < newZ or 
        bottomLeftTile.z < newZ or bottomRightTile.z < newZ) then
        return false
    end

    return true
end

function player:getTile(x, y)
    local tileX = math.floor(x / 32) + 1
    local tileY = math.floor(y / 32) + 1
    return {
        v = mapArray[tileY][tileX][1],
        z = mapArray[tileY][tileX][2]
    }
end

function player:canPlow(tx, ty)
    if mapArray[ty] and mapArray[ty][tx] then
        local tile = mapArray[ty][tx]
        return tile[1] == 1 and tile[2] == self.z
    end
    return false
end

function player:canSow(tx, ty)
    if mapArray[ty] and mapArray[ty][tx] then
        local tile = mapArray[ty][tx]
        return tile[1] == 56 and tile[2] == self.z
    end
    return false
end

function player:canWater(tx, ty)
    if mapArray[ty] and mapArray[ty][tx] then
        local tile = mapArray[ty][tx][1]
        return (tile >= 72 and tile <= 86 and tile % 2 == 0) and mapArray[ty][tx][2] == self.z
    end
    return false
end

function player:canPickUp()
    for _, obj in ipairs(object.objects) do
        local dx = self.x - obj.x
        local dy = self.y - obj.y
        local distance = math.sqrt(dx * dx + dy * dy)
        local isFacing = false
        if self.direction == "Up" and dy > 0 then
            isFacing = true
        elseif self.direction == "Down" and dy < 0 then
            isFacing = true
        elseif self.direction == "Left" and dx > 0 then
            isFacing = true
        elseif self.direction == "Right" and dx < 0 then
            isFacing = true
        end
        if distance < 50 and isFacing then
            return true
        end
    end
    return false
end

function player:draw(cameraX, cameraY)
    local characterScreenX = self.x - cameraX
    local characterScreenY = self.y - cameraY
    local flipX = self.direction == "Left" and -1 or 1
    local flipOffsetX = self.direction == "Left" and 100 or 0
    local spriteNumber = spriteMap.Cody[self.state][self.direction].frames[self.frame].sprite

    love.graphics.setCanvas(canvas.temp)
    love.graphics.draw(self.spriteSheet, self.quads[spriteNumber], 100 - 56, 100 - 56, 0, flipX, 1, flipOffsetX, 0)

    if shadow.frame == shadow.frequency then
        love.graphics.setShader(shader.sprite)
        love.graphics.setBlendMode('alpha')
        shader.sprite:send("angle", shadow.angle)
        shader.sprite:send("colorMapCanvas", canvas.colorMap)
        shader.sprite:send("spriteHeight", 200.0)
        shader.sprite:send("spriteWidth", 200.0)
        shader.sprite:send("spriteBase", ((200-112)/2+80))
        shader.sprite:send("xstart", ((200-112)/2+30))
        shader.sprite:send("xend", ((200-112)/2+80))
        shader.sprite:send("shadowSize", 70.0)
        shader.sprite:send("divideBy", -1*(self.z-self.shadowZ)/64 + 1.5)
        shader.sprite:send("opacity", 1 - -1*(self.z-self.shadowZ)/5/64)
        shader.sprite:send("canvasSize", {window.width, window.height})
        shader.sprite:send("spotlight", {self.x + 8 - cameraX, self.y - cameraY + self.z/2})
        shader.sprite:send("showSpotlight", 0)
        love.graphics.setCanvas(canvas.shadow)
        love.graphics.draw(canvas.temp, characterScreenX + 16 - 100, characterScreenY - 128 + self.shadowZ)
        love.graphics.setShader()
    end

    love.graphics.setCanvas(canvas.object)
    love.graphics.draw(canvas.temp, characterScreenX + 16 - 100, characterScreenY - 128 + self.z)

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
            characterScreenY - 64 + self.z + pageOffsetY,
            0,
            1,
            1,
            0,
            0
        )
        if self.frame == 2 and self.direction == "Down" then 
            love.graphics.draw(self.spriteSheet, self.quads[97], characterScreenX + 16 - 55, characterScreenY - 84 + self.z, 0, flipX, 1, flipOffsetX, 0)
        end
    end
end

function player:drawOutline(cameraX, cameraY, mapArray)
    if self.isNearOutlinedObject then return end

    if not toolbarMap then
        if not toolbarMapErrorPrinted then
            print("Error: toolbarMap is nil in player:drawOutline")
            toolbarMapErrorPrinted = true
        end
        return
    end

    local slot = toolbarMap.slots[toolbarMap.visibleSlots[ui.highlightedSlot]]
    local tool = slot.name
    local isSeed = tool:find("Seed")
    if tool ~= "Hoe" and not isSeed and tool ~= "Watering Can" then return end

    love.graphics.setCanvas(canvas.offscreen)
    love.graphics.setColor(1, 1, 0, 1)

    local tx, ty = self:getTargetTile()
    local z = mapArray[ty] and mapArray[ty][tx] and mapArray[ty][tx][2]
    local drawOutline = (tool == "Hoe" and self:canPlow(tx, ty)) or
                        (isSeed and self:canSow(tx, ty)) or
                        (tool == "Watering Can" and self:canWater(tx, ty))

    if drawOutline then
        local x = (tx - 1) * sprites.size - cameraX
        local y = (ty - 1) * sprites.size - cameraY
        love.graphics.rectangle("line", x, y + z, sprites.size, sprites.size)
    end
    love.graphics.setColor(1, 1, 1, 1)
end
