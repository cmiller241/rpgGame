-- Create the player as a physics object in the world
player = {}

-- Load the player sprite sheet
player.spriteSheet = love.graphics.newImage("img/sprites-fixedgrid.png")

-- Load the player quads
player.quads = {}
for i = 1, math.ceil(player.spriteSheet:getHeight() / 112) do
    for j = 1, math.ceil(player.spriteSheet:getWidth() / 112) do
        player.quads[(i - 1) * math.ceil(player.spriteSheet:getWidth() / 112) + j] = love.graphics.newQuad((j-1) * 112, (i-1) * 112, 112, 112, player.spriteSheet:getDimensions())        
    end
end

-- Assign player-specific properties directly to the player object
player.x = 100  -- Initial x-position
player.y = 250  -- Initial y-position
player.z = 0  -- Vertical position for jumps or other height-related behavior
player.shadowZ = 0  -- Position of the player's shadow on the ground

-- Movement and friction properties
player.friction = 0.99  -- Friction to slow down the player's movement
player.speed = 10  -- Movement speed
player.zSpeed = 0.5  -- Speed along the z-axis (used for jumping)
player.speedLimit = 4  -- Maximum speed limit for the player
player.ax = 0  -- Acceleration in the x-direction
player.ay = 0  -- Acceleration in the y-direction
player.az = 0  -- Acceleration in the z-direction
player.vx = 0  -- Velocity in the x-direction
player.vy = 0  -- Velocity in the y-direction
player.vz = 0  -- Velocity in the z-direction (vertical)

-- Animation-related properties
player.frame = 1  -- Current animation frame
player.frameTime = 0  -- Timer for animation frame changes
player.frameDuration = 0.2  -- Default duration of each frame (overridden for Plowing, Sowing, Watering)
player.plowingTime = 0  -- Timer for plowing animation duration
player.plowedThisAnimation = false  -- Flag to prevent multiple tile updates during plowing
player.sowingTime = 0  -- Timer for sowing animation duration
player.sowedThisAnimation = false  -- Flag to prevent multiple tile updates during sowing
player.wateringTime = 0  -- Timer for watering animation duration
player.wateredThisAnimation = false  -- Flag to prevent multiple tile updates during watering

-- Direction and state
player.direction = "Down"  -- Direction the player is facing ("Up", "Down", "Left", "Right")
player.state = "Standing"  -- Current action state (e.g., "Standing", "Walking", "Jumping", "Plowing", "Sowing", "Watering")

-- Jumping-related properties
player.jump = false  -- Whether the player is currently jumping
player.jumpForce = -13  -- Force applied when jumping
player.isOnGround = true  -- Boolean for checking if the player is grounded

-- Gravity and other movement properties
player.gravity = 0.1  -- Force pulling the player down (for jumping mechanics)
player.gravityFactor = 250  -- Factor to adjust gravity for different scenarios
player.speedCharacter = 10  -- Additional or alternative speed for the character

-- Flag to prevent repeated debug prints
local toolbarMapErrorPrinted = false

function player:update(dt)
    -- Save the previous state and direction for animation purposes
    local previousState = self.state
    local previousDirection = self.direction

    -- Set frame duration based on state
    local frameDuration = (self.state == "Plowing" or self.state == "Sowing" or self.state == "Watering") and 0.125 or 0.2

    -- Update the animation frame timing
    self.frameTime = self.frameTime + dt
    if self.frameTime >= frameDuration then
        self.frame = self.frame + 1
        self.frameTime = 0

        -- Get the number of frames in the current state and direction's animation
        local numFrames = #spriteMap["Cody"][self.state][self.direction]
        if self.frame > numFrames then
            if self.state == "Plowing" or self.state == "Sowing" or self.state == "Watering" then
                self.state = "Standing" -- Return to Standing after Plowing, Sowing, or Watering completes
                self.frame = 1
                self.plowedThisAnimation = false -- Reset for next plowing
                self.sowedThisAnimation = false -- Reset for next sowing
                self.wateredThisAnimation = false -- Reset for next watering
            else
                self.frame = 1 -- Loop non-Plowing/Sowing/Watering animations
            end
        end

        -- Update map tile to 56 when transitioning to frame 4 in Plowing
        if self.state == "Plowing" and self.frame == 4 and not self.plowedThisAnimation then
            local playerTileX = math.floor((self.x + 16) / sprites.size) + 1
            local playerTileY = math.floor(self.y / sprites.size) + 1
            local targetTileX, targetTileY = playerTileX, playerTileY
            if self.direction == "Left" then
                targetTileX = playerTileX - 1
            elseif self.direction == "Right" then
                targetTileX = playerTileX + 1
            elseif self.direction == "Up" then
                targetTileY = playerTileY - 1
            elseif self.direction == "Down" then
                targetTileY = playerTileY + 1
            end
            -- Ensure the target tile is within map bounds and can be plowed
            if self:canPlow(targetTileX, targetTileY) then
                mapArray[targetTileY][targetTileX][1] = 56 -- Set tile type to 56 (dirt)
                self.plowedThisAnimation = true -- Prevent multiple updates
            end
        end

        -- Update map tile to 72 when transitioning to second-to-last frame in Sowing
        if self.state == "Sowing" and self.frame == numFrames - 1 and not self.sowedThisAnimation then
            local playerTileX = math.floor((self.x + 16) / sprites.size) + 1
            local playerTileY = math.floor(self.y / sprites.size) + 1
            local targetTileX, targetTileY = playerTileX, playerTileY
            if self.direction == "Left" then
                targetTileX = playerTileX - 1
            elseif self.direction == "Right" then
                targetTileX = playerTileX + 1
            elseif self.direction == "Up" then
                targetTileY = playerTileY - 1
            elseif self.direction == "Down" then
                targetTileY = playerTileY + 1
            end
            -- Ensure the target tile is within map bounds and can be sowed
            if self:canSow(targetTileX, targetTileY) then
                mapArray[targetTileY][targetTileX][1] = 72 -- Set tile type to 72 (ground with seeds)
                self.sowedThisAnimation = true -- Prevent multiple updates
            end
        end

        -- Update map tile to 73 when transitioning to frame 3 in Watering
        if self.state == "Watering" and self.frame == 3 and not self.wateredThisAnimation then
            local playerTileX = math.floor((self.x + 16) / sprites.size) + 1
            local playerTileY = math.floor(self.y / sprites.size) + 1
            local targetTileX, targetTileY = playerTileX, playerTileY
            if self.direction == "Left" then
                targetTileX = playerTileX - 1
            elseif self.direction == "Right" then
                targetTileX = playerTileX + 1
            elseif self.direction == "Up" then
                targetTileY = playerTileY - 1
            elseif self.direction == "Down" then
                targetTileY = playerTileY + 1
            end
            -- Ensure the target tile is within map bounds and can be watered
            if self:canWater(targetTileX, targetTileY) then
                mapArray[targetTileY][targetTileX][1] = 73 -- Set tile type to 73 (watered seeds)
                self.wateredThisAnimation = true -- Prevent multiple updates
            end
        end
    end

    -- Update plowing timer
    if self.state == "Plowing" then
        self.plowingTime = self.plowingTime + dt
        if self.plowingTime >= 0.5 then
            self.state = "Standing"
            self.frame = 1
            self.frameTime = 0
            self.plowingTime = 0
            self.plowedThisAnimation = false -- Reset for next plowing
        end
    end

    -- Update sowing timer
    if self.state == "Sowing" then
        self.sowingTime = self.sowingTime + dt
        if self.sowingTime >= 0.5 then
            self.state = "Standing"
            self.frame = 1
            self.frameTime = 0
            self.sowingTime = 0
            self.sowedThisAnimation = false -- Reset for next sowing
        end
    end

    -- Update watering timer
    if self.state == "Watering" then
        self.wateringTime = self.wateringTime + dt
        if self.wateringTime >= 0.5 then
            self.state = "Standing"
            self.frame = 1
            self.frameTime = 0
            self.wateringTime = 0
            self.wateredThisAnimation = false -- Reset for next watering
        end
    end

    -- Skip movement updates during Plowing, Sowing, or Watering
    if self.state == "Plowing" or self.state == "Sowing" or self.state == "Watering" then
        return
    end

    -- Default state is "Standing" unless input changes it
    if self.state ~= "Jumping-Start" then self.state = "Standing" end

    -- Reset accelerations to 0 before handling input
    self.ax, self.ay = 0, 0

    -- Input handling: Movement keys (Left, Right, Up, Down)
    if love.keyboard.isDown("right") then
        self.ax = self.speed * dt
        self.state = "Walking"
        self.direction = "Right"
    end
    if love.keyboard.isDown("left") then
        self.ax = -self.speed * dt
        self.state = "Walking"
        self.direction = "Left"
    end
    if love.keyboard.isDown("up") then
        self.ay = -self.speed * dt
        self.state = "Walking"
        self.direction = "Up"
    end
    if love.keyboard.isDown("down") then
        self.ay = self.speed * dt
        self.state = "Walking"
        self.direction = "Down"
    end

    -- Reset velocities if no directional keys are pressed
    if not love.keyboard.isDown("right") and not love.keyboard.isDown("left") then
        self.ax = 0
        self.vx = 0
    end
    if not love.keyboard.isDown("up") and not love.keyboard.isDown("down") then
        self.ay = 0
        self.vy = 0
    end

    -- Jumping logic: Check if in mid-air, update state
    if not self.isOnGround then
        if self.vz < 0 then self.state = "Jumping-Up" end
        if self.vz > 0 then self.state = "Jumping-Down" end
    end

    -- Jumping physics
    if self.jump and self.isOnGround then
        self.vz = self.jumpForce
        self.isOnGround = false
        self.jump = false
        print("self.vz is " .. self.vz)
    end

    -- Apply gravity while in air
    self.vz = self.vz + self.gravity * self.gravityFactor * dt

    -- Prevent player from falling below the ground level
    if self.z > 0 then
        self.z = 0
        self.isOnGround = true
    end

    -- Update velocities with friction
    self.vx = (self.vx + self.ax) * self.friction
    self.vy = (self.vy + self.ay) * self.friction

    -- Cap the velocities to avoid exceeding speed limits
    if self.vx < -self.speedLimit then self.vx = -self.speedLimit end
    if self.vx > self.speedLimit then self.vx = self.speedLimit end
    if self.vy < -self.speedLimit then self.vy = -self.speedLimit end
    if self.vy > self.speedLimit then self.vy = self.speedLimit end

    -- Move the character based on velocity and delta time (no collisions considered yet)
    self:moveCharacter(self.vx, self.vy, self.vz * 20 * dt)

    -- Reset the animation frame if state or direction changes
    if self.state ~= previousState or self.direction ~= previousDirection then
        self.frame = 1
        self.frameTime = 0
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
    local right = newX + 32 -- You may want to adjust this to use the player width
    local top = newY - 8    -- You may want to adjust this to use the player height
    local bottom = newY

    local topLeftTile = self:getTile(left, top)
    local topRightTile = self:getTile(right, top)
    local bottomLeftTile = self:getTile(left, bottom)
    local bottomRightTile = self:getTile(right, bottom)

    self.shadowZ = bottomLeftTile.z -- Update the shadow position

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

function player:canPlow(targetTileX, targetTileY)
    -- Check if the target tile is within bounds, is grass (type 1), and has the same elevation as the player
    if targetTileY >= 1 and targetTileY <= #mapArray and targetTileX >= 1 and targetTileX <= #mapArray[targetTileY] then
        local tileType = mapArray[targetTileY][targetTileX][1]
        local tileZ = mapArray[targetTileY][targetTileX][2]
        return tileType == 1 and tileZ == self.z
    end
    return false
end

function player:canSow(targetTileX, targetTileY)
    -- Check if the target tile is within bounds, is dirt (type 56), and has the same elevation as the player
    if targetTileY >= 1 and targetTileY <= #mapArray and targetTileX >= 1 and targetTileX <= #mapArray[targetTileY] then
        local tileType = mapArray[targetTileY][targetTileX][1]
        local tileZ = mapArray[targetTileY][targetTileX][2]
        return tileType == 56 and tileZ == self.z
    end
    return false
end

function player:canWater(targetTileX, targetTileY)
    -- Check if the target tile is within bounds, is seeds (type 72), and has the same elevation as the player
    if targetTileY >= 1 and targetTileY <= #mapArray and targetTileX >= 1 and targetTileX <= #mapArray[targetTileY] then
        local tileType = mapArray[targetTileY][targetTileX][1]
        local tileZ = mapArray[targetTileY][targetTileX][2]
        return tileType == 72 and tileZ == self.z
    end
    return false
end

function player:keypressed(key)
    if key == "space" then
        if self.isOnGround then
            self.state = "Jumping-Start"
            self.direction = "Down"
            self.frame = 1
            local jumpSound = sounds.jump:clone() -- Clone the sound source
            jumpSound:setVolume(0.1) -- Random volume
            jumpSound:play() -- Play jump sound
            print("Space pressed, jump sound played")
        end
    elseif key == "p" then
        if not toolbarMap then
            if not toolbarMapErrorPrinted then
                print("Error: toolbarMap is nil in player:keypressed")
                toolbarMapErrorPrinted = true
            end
            return
        end
        local highlightedQuad = toolbarMap.visibleSlots[ui.highlightedSlot]
        local highlightedTool = toolbarMap.slots[highlightedQuad].name
        if highlightedTool == "Hoe" then
            local playerTileX = math.floor((self.x + 16) / sprites.size) + 1
            local playerTileY = math.floor(self.y / sprites.size) + 1
            local targetTileX, targetTileY = playerTileX, playerTileY
            if self.direction == "Left" then
                targetTileX = playerTileX - 1
            elseif self.direction == "Right" then
                targetTileX = playerTileX + 1
            elseif self.direction == "Up" then
                targetTileY = playerTileY - 1
            elseif self.direction == "Down" then
                targetTileY = playerTileY + 1
            end
            if self:canPlow(targetTileX, targetTileY) then
                self.state = "Plowing"
                self.frame = 1
                self.frameTime = 0
                self.plowingTime = 0
                self.plowedThisAnimation = false
                local shovelSound = sounds.shovel:clone() -- Clone the sound source
                shovelSound:setPitch(love.math.random(0.9, 1.1)) -- Random pitch
                shovelSound:setVolume(love.math.random(0.8, 1.0)) -- Random volume
                shovelSound:play() -- Play shovel sound
                print("P pressed, shovel sound played")
            end
        elseif highlightedTool == "Grass Seed" or highlightedTool == "Tomato Seed" or 
               highlightedTool == "Corn Seed" or highlightedTool == "Potato Seed" or 
               highlightedTool == "Carrot Seed" then
            local playerTileX = math.floor((self.x + 16) / sprites.size) + 1
            local playerTileY = math.floor(self.y / sprites.size) + 1
            local targetTileX, targetTileY = playerTileX, playerTileY
            if self.direction == "Left" then
                targetTileX = playerTileX - 1
            elseif self.direction == "Right" then
                targetTileX = playerTileX + 1
            elseif self.direction == "Up" then
                targetTileY = playerTileY - 1
            elseif self.direction == "Down" then
                targetTileY = playerTileY + 1
            end
            if self:canSow(targetTileX, targetTileY) then
                self.state = "Sowing"
                self.frame = 1
                self.frameTime = 0
                self.sowingTime = 0
                self.sowedThisAnimation = false
                local sowSound = sounds.sow and sounds.sow:clone() or sounds.shovel:clone() -- Fallback to shovel sound if sow sound is missing
                sowSound:setPitch(love.math.random(0.9, 1.1)) -- Random pitch
                sowSound:setVolume(love.math.random(0.8, 1.0)) -- Random volume
                sowSound:play() -- Play sow sound
                print("P pressed, sow sound played")
            end
        elseif highlightedTool == "Watering Can" then
            local playerTileX = math.floor((self.x + 16) / sprites.size) + 1
            local playerTileY = math.floor(self.y / sprites.size) + 1
            local targetTileX, targetTileY = playerTileX, playerTileY
            if self.direction == "Left" then
                targetTileX = playerTileX - 1
            elseif self.direction == "Right" then
                targetTileX = playerTileX + 1
            elseif self.direction == "Up" then
                targetTileY = playerTileY - 1
            elseif self.direction == "Down" then
                targetTileY = playerTileY + 1
            end
            if self:canWater(targetTileX, targetTileY) then
                self.state = "Watering"
                self.frame = 1
                self.frameTime = 0
                self.wateringTime = 0
                self.wateredThisAnimation = false
                local waterSound = sounds.water and sounds.water:clone() or sounds.shovel:clone() -- Fallback to shovel sound if water sound is missing
                waterSound:setPitch(love.math.random(0.9, 1.1)) -- Random pitch
                waterSound:setVolume(love.math.random(0.8, 1.0)) -- Random volume
                waterSound:play() -- Play water sound
                print("P pressed, water sound played")
            end
        end
        -- If another tool is selected, do nothing for now
    end
end

function player:keyreleased(key)
    if key == "space" then
        print("Space key released")
        print("The self.jump is " .. tostring(self.jump))
        print("The self.isOnGround is " .. tostring(self.isOnGround))

        if self.jump == false and self.isOnGround == true then
            self.jump = true
            print("The self.jump NOW is " .. tostring(self.jump))
        end
    end
end

function player:draw(cameraX, cameraY)
    local characterScreenX = player.x - cameraX
    local characterScreenY = player.y - cameraY

    local flipX = 1
    local flipOffsetX = 0
    if player.direction == "Left" then
        flipX = -1
        flipOffsetX = 200/2
    end

    local spriteNumber = spriteMap["Cody"][player.state][player.direction][player.frame]

    love.graphics.setCanvas(canvas.temp)
    love.graphics.draw(
        player.spriteSheet,
        player.quads[spriteNumber],
        200/2 - 112/2,
        200/2 - 112/2,
        0,
        flipX,
        1,
        flipOffsetX,
        0
    )

    if shadow.frame == shadow.frequency then
        love.graphics.setShader(shader.sprite)
        love.graphics.setBlendMode('alpha')
        shader.sprite:send("angle", shadow.angle)   
        shader.sprite:send("colorMapCanvas", canvas.colorMap)
        shader.sprite:send("spriteHeight",200.0)
        shader.sprite:send("spriteWidth",200.0)
        shader.sprite:send("spriteBase", ((200-112)/2+80))
        shader.sprite:send("xstart", ((200-112)/2+30)) --43
        shader.sprite:send("xend", ((200-112)/2+80)) --71
        shader.sprite:send("shadowSize", 70.0)
        shader.sprite:send("divideBy", -1*(player.z-player.shadowZ)/64 + 1.5)
        shader.sprite:send("opacity", 1 - -1*(player.z-player.shadowZ)/5/64)
        shader.sprite:send("canvasSize", {window.width, window.height})
        shader.sprite:send("spotlight", {player.x + 8 - cameraX, player.y - cameraY + player.z/2})
        shader.sprite:send("showSpotlight", 0)
        love.graphics.setCanvas(canvas.shadow)
        love.graphics.draw(
            canvas.temp,
            characterScreenX + 32/2 - 200/2,
            characterScreenY - 128 + player.shadowZ
        )
        love.graphics.setShader()
    end

    love.graphics.setCanvas(canvas.object)
    love.graphics.draw(
        canvas.temp,
        characterScreenX + 32/2 - 200/2,
        characterScreenY - 128 + player.z
    )
end

function player:drawOutline(cameraX, cameraY, mapArray)
    if not toolbarMap then
        if not toolbarMapErrorPrinted then
            print("Error: toolbarMap is nil in player:drawOutline")
            toolbarMapErrorPrinted = true
        end
        return
    end
    local highlightedQuad = toolbarMap.visibleSlots[ui.highlightedSlot]
    local highlightedTool = toolbarMap.slots[highlightedQuad].name
    local isSeed = highlightedTool == "Grass Seed" or highlightedTool == "Tomato Seed" or 
                   highlightedTool == "Corn Seed" or highlightedTool == "Potato Seed" or 
                   highlightedTool == "Carrot Seed"
    if highlightedTool ~= "Hoe" and not isSeed and highlightedTool ~= "Watering Can" then
        return
    end

    love.graphics.setCanvas(canvas.offscreen)
    love.graphics.setColor(1, 1, 0, 1) -- Yellow outline for visibility
    local playerTileX = math.floor((self.x + 16) / sprites.size) + 1
    local playerTileY = math.floor(self.y / sprites.size) + 1
    local targetTileX, targetTileY = playerTileX, playerTileY
    if self.direction == "Left" then
        targetTileX = playerTileX - 1
    elseif self.direction == "Right" then
        targetTileX = playerTileX + 1
    elseif self.direction == "Up" then
        targetTileY = playerTileY - 1
    elseif self.direction == "Down" then
        targetTileY = playerTileY + 1
    end
    -- Draw outline based on tool: grass (type 1) for Hoe, dirt (type 56) for seeds, seeds (type 72) for Watering Can
    if highlightedTool == "Hoe" and self:canPlow(targetTileX, targetTileY) then
        local targetX = (targetTileX - 1) * sprites.size - cameraX
        local targetY = (targetTileY - 1) * sprites.size - cameraY
        local z = mapArray[targetTileY][targetTileX][2]
        love.graphics.rectangle("line", targetX, targetY + z, sprites.size, sprites.size)
    elseif isSeed and self:canSow(targetTileX, targetTileY) then
        local targetX = (targetTileX - 1) * sprites.size - cameraX
        local targetY = (targetTileY - 1) * sprites.size - cameraY
        local z = mapArray[targetTileY][targetTileX][2]
        love.graphics.rectangle("line", targetX, targetY + z, sprites.size, sprites.size)
    elseif highlightedTool == "Watering Can" and self:canWater(targetTileX, targetTileY) then
        local targetX = (targetTileX - 1) * sprites.size - cameraX
        local targetY = (targetTileY - 1) * sprites.size - cameraY
        local z = mapArray[targetTileY][targetTileX][2]
        love.graphics.rectangle("line", targetX, targetY + z, sprites.size, sprites.size)
    end
    love.graphics.setColor(1, 1, 1, 1) -- Reset color
end