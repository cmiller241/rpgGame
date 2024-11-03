-- Create the shadow table
shadow = {}

-- Assign shadow-related variables
shadow.angle = 120
shadow.size = 32
shadow.showColorMap = false
shadow.frequency = 1  -- How many frames before recalculating shadows
shadow.frame = 0      -- Current shadow frame
shadow.rotationSpeed = 1

-- Shadow update function to handle input and shadow calculations
function shadow:update(dt)
    -- Handle angle rotation for shadows
    if love.keyboard.isDown('m') then
        self.angle = self.angle + self.rotationSpeed * dt
    end
    if love.keyboard.isDown('n') then
        self.angle = self.angle - self.rotationSpeed * dt
        if self.angle < 0 then self.angle = 0 end  -- Keep angle within a valid range
    end

end

--Let's only calculate shadow placement every few frames to save on performance. 
function shadow:check()
    shadow.frame = shadow.frame + 1
    if shadow.frame == shadow.frequency then
        love.graphics.setCanvas(canvas.shadow)
        love.graphics.clear(0,0,0,0)
    end
    if shadow.frame > shadow.frequency then
        shadow.frame = 0
    end
end