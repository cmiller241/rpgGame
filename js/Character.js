class Character {
    constructor (id, x, y, width, height) {
        this.id = id;
        this.x = x;
        this.y = y;
        this.z = 0;
        this.base=84;
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
        this.footprint = 7;
        this.frame = 0;
        this.speedLimit = 10;
        this.isOnGround = true;
        this.lastFrameUpdate = 0;
    }

    moveCharacter(dx, dy, mapArray) {
        const newX = Math.round(this.x + dx);
        const newY = Math.round(this.y + dy);

        if (this.canMoveTo(newX, newY, mapArray)) {
            this.x = newX;
            this.y = newY;  
        }
    }

    canMoveTo(newX, newY, mapArray) {
        //Calculate the character's bounding box
        const left = newX;
        const right = newX + this.width;
        const top = newY - this.footprint;;
        const bottom = newY;

        const topLeftTile = this.getTile(left, top, mapArray);
        const topRightTile = this.getTile(right, top, mapArray);
        const bottomLeftTile = this.getTile(left, bottom, mapArray);
        const bottomRightTile = this.getTile(right, bottom, mapArray);

        if (topLeftTile.v != 1 || topRightTile.v != 1 || bottomLeftTile.v != 1 || bottomRightTile.v != 1 ||
            topLeftTile.z < this.z || topRightTile.z < this.z || bottomLeftTile.z < this.z || bottomRightTile.z < this.z) {
            return false;
        }

        //The character can move
        return true;
    }

    getTile(x, y, mapArray) {
        const tileX = Math.floor(x / 32);
        const tileY = Math.floor(y / 32);
        console.log("tileX is " + tileX + " and tileY is " + tileY);
        return {
            v: mapArray[tileY][tileX].v,
            z: mapArray[tileY][tileX].z
        };
    }

    update(mapArray) {
        const now = Date.now();
        console.log("this.moveRight is " + this.moveRight);

        if (this.moveRight) {
            this.ax = 1;
            this.direction = "Right";
            this.action = "Walking";
        }
        if (this.moveLeft) {
            this.ax = -1;
            this.direction = "Left";
            this.action = "Walking";
        }
        if (this.moveUp) {
            this.ay = -1;
            this.direction = "Up";
            this.action = "Walking";
        }
        if (this.moveDown) {
            this.ay = 1;
            this.direction = "Down";
            this.action = "Walking";
        }   
        if (!this.moveRight && !this.moveLeft) {
            this.ax = 0;
            this.vx = 0;
            //this.action = "Standing";
        }
        if (!this.moveUp && !this.moveDown) {   
            this.ay = 0;
            this.vy = 0;    
            //this.action = "Standing";
        }
        if (!this.moveRight && !this.moveLeft && !this.moveUp && !this.moveDown) {
            this.action = "Standing";
        }

        //Apply acceleration
        this.vx += this.ax;
        this.vy += this.ay;

        //Apply friction
        this.vx *= this.friction;
        this.vy *= this.friction;

        //Apply Speed Limit
        if (this.vx > this.speedLimit) this.vx = this.speedLimit;
        if (this.vx < -this.speedLimit) this.vx = -this.speedLimit;
        if (this.vy > this.speedLimit) this.vy = this.speedLimit;
        if (this.vy < -this.speedLimit) this.vy = -this.speedLimit;

        //Apply velocities to x and y values
        // this.x = Math.round(this.x + this.vx);
        // this.y = Math.round(this.y + this.vy);       

        this.moveCharacter(this.vx, this.vy, mapArray);

        //Check for collisions
        
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