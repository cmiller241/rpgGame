class Character {
    constructor (id, x, y, width, height) {
        this.id = id;
        this.x = x;
        this.y = y;
        this.z = 0;
        this.base=96;
        this.width = width;
        this.height = height;
        this.moveRight = false;
        this.moveLeft = false;
        this.moveUp = false;
        this.moveDown = false;
        this.sprite = "Cody";
        this.direction = "Down";
        this.action = "Standing";
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
        this.lastFrameUpdate = 0;
    }

    update() {
        const now = Date.now();

        if (!this.lastFrameUpdate) {
            this.lastFrameUpdate = now;
        }

        if (now - this.lastFrameUpdate >= 200) {
            this.frame++;
            this.lastFrameUpdate = now;
        }

        if (this.frame >= spriteMap[this.sprite][this.action][this.direction].length) {
            this.frame = 0;
            //console.log("The frame has been zeroed out");
        }
    }
}