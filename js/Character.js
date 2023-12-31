class Character {
    constructor (id, x, y, width, height) {
        this.id = id;
        this.x = x;
        this.y = y;
        this.z = 0;
        this.base=84;
        this.shadowX=10;
        this.shadowY=10;
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
        this.gravity = 0.3;
        this.friction = .96;
        this.ax = 0;
        this.ay = 0;
        this.az = 0;
        this.vx = 0;
        this.vy = 0;
        this.vz = 0;
        this.footprint = 7;             //We collision detect from base of character up footprint pixels
        this.lovehandles = 3;           //We collision detect from horizontal ends of character out lovehandles pixels
        this.frame = 0;
        this.speedLimit = 10;
        this.isOnGround = true;
        this.lastFrameUpdate = 0;
    }

    moveCharacter(dx, dy, dz, mapArray) {

        const newX = Math.round(this.x + dx);
        const newY = Math.round(this.y + dy);
        const newZ = Math.round(this.z + dz);

        const canMoveXY = this.canMoveTo(newX, newY, this.z, mapArray);
        const canMoveZ = this.canMoveTo(this.x, this.y, newZ, mapArray);

        if (canMoveXY) {
            this.x = newX;
            this.y = newY;  
        } else {
            this.vx = 0;
            this.vy = 0;
        }

        if (canMoveZ) {
            this.z = newZ;
        } else {
            this.vz = 0;
            this.isOnGround = true;
        }

    }

    canMoveTo(newX, newY, newZ, mapArray) {
        //Calculate the character's bounding box
        const left = newX + this.lovehandles;
        const right = newX + this.width - this.lovehandles*2;
        const top = newY - this.footprint;;
        const bottom = newY;

        const topLeftTile = this.getTile(left, top, mapArray);
        const topRightTile = this.getTile(right, top, mapArray);
        const bottomLeftTile = this.getTile(left, bottom, mapArray);
        const bottomRightTile = this.getTile(right, bottom, mapArray);

        this.shadowX = Math.round((left + right) / 2);       //This is the best place to calculate shadow placement
        this.shadowY = Math.round((top + bottom) / 2) + bottomLeftTile.z;       //Despite being irrelevant to collision detection

        if (topLeftTile.v > 500 || topRightTile.v > 500  || bottomLeftTile.v > 500 || bottomRightTile.v > 500 ||
            topLeftTile.z < newZ || topRightTile.z < newZ || bottomLeftTile.z < newZ || bottomRightTile.z < newZ) {
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
            v: mapArray[tileY]?.[tileX]?.v,
            z: mapArray[tileY]?.[tileX]?.z
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
        if (this.isOnGround == false) {
            if (this.vz < 0 ) this.action = "Jumping-Up";
            if (this.vz > 0 ) this.action = "Jumping-Down";
        }
        if (this.jump && this.isOnGround) {
            this.vz = this.jumpForce;
            this.jump = false;
            this.isOnGround = false;
        }

        //Apply acceleration
        this.vx += this.ax;
        this.vy += this.ay;
        this.vz += this.az;

        //Apply friction
        this.vx *= this.friction;
        this.vy *= this.friction;
        if (this.vz < 0) this.vz *= this.friction;

        //Apply gravity
        this.vz += this.gravity;

        //Apply Speed Limit
        if (this.vx > this.speedLimit) this.vx = this.speedLimit;
        if (this.vx < -this.speedLimit) this.vx = -this.speedLimit;
        if (this.vy > this.speedLimit) this.vy = this.speedLimit;
        if (this.vy < -this.speedLimit) this.vy = -this.speedLimit;

        //Apply velocities to x and y values
        // this.x = Math.round(this.x + this.vx);
        // this.y = Math.round(this.y + this.vy);       

        this.moveCharacter(this.vx, this.vy, this.vz, mapArray);
        //this.z += this.vz;

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