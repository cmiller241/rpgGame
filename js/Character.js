class Character {
    constructor (id, x, y, width, height) {
        this.id = id;
        this.x = x;
        this.y = y;
        this.z = 0;
        this.width = width;
        this.height = height;
        this.moveRight = false;
        this.moveLeft = false;
        this.moveUp = false;
        this.moveDown = false;
        this.jump = false;
        this.jumpForce = -8;
        this.gravity = 0.5;
        this.friction = .96;
        this.ax = 0;
        this.ay = 0;
        this.az = 0;
        this.vx = 0;
        this.vy = 0;
        this.vz = 0;
        this.frame = 0;
        this.speedLimit = 5;
        this.isOnGround = true;
    }
}