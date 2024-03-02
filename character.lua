Character = {}
Character.__index = Character

function Character.new(id, x, y, width, height)
    local self = setmetatable({}, Character)
    self.id = id
    self.x = x
    self.y = y
    self.z = 0
    self.base = 84
    self.shadowX = 10
    self.shadowY = 10
    self.width = width
    self.height = height
    self.moveRight = false
    self.moveLeft = false
    self.moveUp = false
    self.moveDown = false
    self.sprite = "Cody"
    self.direction = "Down"
    self.action = "Standing"
    self.jump = false
    self.jumpForce = -8
    self.gravity = 0.3
    self.friction = 0.96
    self.ax = 0
    self.ay = 0
    self.az = 0
    self.vx = 0
    self.vy = 0
    self.vz = 0
    self.footprint = 7
    self.lovehandles = 3
    self.frame = 0
    self.speedLimit = 10
    self.isOnGround = true
    self.lastFrameUpdate = 0
    return self
end

return Character