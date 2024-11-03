-- Create the player as a physics object in the world
player = {}

-- Load the player sprite sheet
player.spriteSheet = love.graphics.newImage("img/sprites-fixedgrid.png")

--Load the player quads
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
player.speedLimit = 2  -- Maximum speed limit for the player
player.ax = 0  -- Acceleration in the x-direction
player.ay = 0  -- Acceleration in the y-direction
player.az = 0  -- Acceleration in the z-direction
player.vx = 0  -- Velocity in the x-direction
player.vy = 0  -- Velocity in the y-direction
player.vz = 0  -- Velocity in the z-direction (vertical)

-- Animation-related properties
player.frame = 1  -- Current animation frame
player.frameTime = 0  -- Timer for animation frame changes
player.frameDuration = 0.2  -- Duration of each frame in the animation

-- Direction and state
player.direction = "Down"  -- Direction the player is facing ("Up", "Down", "Left", "Right")
player.state = "Standing"  -- Current action state (e.g., "Standing", "Walking", "Jumping")

-- Jumping-related properties
player.jump = false  -- Whether the player is currently jumping
player.jumpForce = -8  -- Force applied when jumping
player.isOnGround = true  -- Boolean for checking if the player is grounded

-- Gravity and other movement properties
player.gravity = 30  -- Force pulling the player down (for jumping mechanics)
player.gravityFactor = 500  -- Factor to adjust gravity for different scenarios
player.speedCharacter = 10  -- Additional or alternative speed for the character

function player:update(dt)
    -- Save the previous state and direction for animation purposes
    local previousState = self.state
    local previousDirection = self.direction

    -- Update the animation frame timing
    self.frameTime = self.frameTime + dt
    if self.frameTime >= self.frameDuration then
        self.frame = self.frame + 1
        self.frameTime = 0

        -- Get the number of frames in the current state and direction's animation
        local numFrames = #spriteMap["Cody"][self.state][self.direction]
        if self.frame > numFrames then self.frame = 1 end
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

function player:keypressed(key)
    if key == "space" then
        self.state = "Jumping-Start"
        self.direction = "Down"
        self.frame = 1
    end
end

function player:keyreleased(key)
    if key == "space" then
        if (self.jump == false and self.isOnGround == true) then
            self.jump = true
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
        shader.sprite:send("spriteLeftX", characterScreenX + 32/2 - 200/2)    
        shader.sprite:send("spriteTopY", characterScreenY - 128 + player.shadowZ)
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
            characterScreenY - 128 + player.shadowZ --+ playerZ       --128 = base + (200-112)/2 
        )
        love.graphics.setShader()
    end

    love.graphics.setCanvas(canvas.object)
    love.graphics.draw(
        canvas.temp,
        characterScreenX + 32/2  - 200/2,
        characterScreenY - 128 + player.z       --128 = base + (200-112)/2 
    )

end
