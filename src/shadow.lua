-- Create the shadow table
shadow = {}

-- Assign shadow-related variables
shadow.angle = 0
shadow.size = 32
shadow.showColorMap = false
shadow.frequency = 0  -- How many frames before recalculating shadows
shadow.frame = 0      -- Current shadow frame
shadow.rotationSpeed = 5
shadow.dayLength = 1200  -- Length of one day/night cycle in seconds (1200 = 20 minutes)
shadow.totalDegrees = 360  -- Total degrees in a full cycle
shadow.dayNightCycleSpeed = shadow.totalDegrees / shadow.dayLength  -- degrees per second
shadow.timer = 0

-- Shadow update function to handle input and shadow calculations
function shadow:update(dt)
    -- Update the timer with the delta time
    self.timer = self.timer + dt
    
    -- Automatically update the angle for day/night cycle based on the timer
    if self.timer >= 1 then  -- Update every second
        self.angle = self.angle + self.dayNightCycleSpeed  -- Update angle based on the cycle speed
        if self.angle >= 360 then
            self.angle = self.angle - 360  -- Keep angle within a valid range
        end
        
        self.timer = self.timer - 1  -- Decrement the timer
    end

    -- Handle manual angle rotation for shadows
    if love.keyboard.isDown('m') then
        self.angle = self.angle + self.rotationSpeed * dt
    end
    if love.keyboard.isDown('n') then
        self.angle = self.angle - self.rotationSpeed * dt
        if self.angle < 0 then 
            self.angle = 359  -- Keep angle within a valid range
        end
    end
end

--Let's only calculate shadow placement every few frames to save on performance. 
function shadow:check()
    --shadow.frame = shadow.frame + 1
    --if shadow.frame == shadow.frequency then
    --    love.graphics.setCanvas(canvas.shadow)
    --    love.graphics.clear(0,0,0,0)
    --end
    --if shadow.frame > shadow.frequency then
    --    shadow.frame = 0
    --end
end