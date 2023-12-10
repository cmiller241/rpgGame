const keyBoardState = new KeyboardState();

class Game {
    constructor(canvas) {
        this.canvas = canvas;
        this.fixedWidth = 800;
        this.fixedHeight = 800;
        this.tileWidth = 32;
        this.tileHeight = 32;
        this.sheetWidth = 352;
        this.sheetHeight = 640;
        this.sheetCol = this.sheetWidth / this.tileWidth;
        this.sheetRow = this.sheetHeight / this.tileHeight;
        this.canvasXNum = Math.floor(this.canvas.width / this.tileWidth);
        this.canvasYNum = Math.floor(this.canvas.height / this.tileHeight);
        this.drawingSurface = this.canvas.getContext("2d");
        this.drawingSurface.imageSmoothingEnabled = false;
        this.drawingSurface.mozImageSmoothingEnabled = false;
        this.drawingSurface.webkitImageSmoothingEnabled = false;
        this.playerX = 0;
        this.playerY = 0;
        this.scale = 2;
        this.loadHandler = new LoadHandler();
        this.map = new Map(100,100,'maps/map01.js');

        this.characters = [];
        this.characters[0] = new Character(0,100,100,32,32);
    }

    resizeCanvas() {

        this.canvas.width = window.innerWidth;

        this.canvas.style.width = Math.floor(this.scale*100) + "%";
        
        this.canvas.height = window.innerHeight;

        this.canvasXNum = Math.floor(this.canvas.width / this.tileWidth);
        this.canvasYNum = Math.floor(this.canvas.height / this.tileHeight);
    }

    start() {
        this.resizeCanvas();
        window.addEventListener('resize', this.resizeCanvas);

        Promise.all([
            this.map.load(),
            this.loadHandler.loadAllImages([
                {src: 'img/sprites2.png'},
                {src: 'img/sprites-fixedgrid.png'},
                {src: 'img/leaf4.png'},
                {src: 'img/treesprite2.png'},
                {src: 'img/grass.png'},
                {src: 'img/ui.png'},
                {src: 'img/lanternlight.png'},
                {src: 'img/chicken.png'}
           ])
        ]).then(() => {
            console.log("All assets loaded successfully!");
            //setInterval(() => this.update(),1000/60);
            this.update();
            this.render();
        }).catch((error) => {
            console.log("Error loading assets", error);
        })
    }

    update() {
        //Create code to calculate FPS
        // const now = performance.now();
        // let deltaTime = 0;
        // if (this.lastUpdate) {
        //     const elapsed = now - this.lastUpdate;
        //     deltaTime = elapsed / 1000;
        //     const fps = 1 / deltaTime;
        //     //console.log(`FPS: ${fps}`);
        // }
        // this.lastUpdate = now;

        this.characters.forEach(character => character.update()); //Update all characters' frames

        //Player movement
        this.characters[0].action = "Standing";
        if (keyBoardState.isDown("ArrowLeft")) {
            this.characters[0].x -= 2;
            this.characters[0].direction = "Left";
            this.characters[0].action= "Walking";
        } 
        if (keyBoardState.isDown("ArrowRight")) {
            this.characters[0].x += 2;
            this.characters[0].direction = "Right";
            this.characters[0].action = "Walking";
        } 
        if (keyBoardState.isDown("ArrowUp")) {
            this.characters[0].y -= 2;
            this.characters[0].direction = "Up";
            this.characters[0].action= "Walking";
        } 
        if (keyBoardState.isDown("ArrowDown")) {
            this.characters[0].y += 2;
            this.characters[0].direction = "Down";
            this.characters[0].action= "Walking";
        }
        if (keyBoardState.isDown("KeyP")) {
            this.scale += 0.1;
            this.resizeCanvas();
            console.log("The scale is " + this.scale);
        }
        if (keyBoardState.isDown("KeyL")) {
            this.scale -= 0.1;
            if (this.scale < 0.1) this.scale = 0.1;
            this.resizeCanvas();
            console.log("The scale is " + this.scale);
        }
 
        window.requestAnimationFrame(() => this.update());
 
        //console.log("The playerX is " + this.playerX + " and the playerY is " + this.playerY);

    }

    render() {
        this.drawingSurface.clearRect(0,0,this.canvas.width,this.canvas.height);    //
        //const rect = this.canvas.getBoundingClientRect();
        var camX = Math.floor(this.characters[0].x - Math.floor(this.canvas.width/2/this.scale));     //Camera begins half stage from center of player
        var camY = Math.floor(this.characters[0].y - Math.floor(this.canvas.height/2/this.scale));     //Camera begins half stage from center of player
        if (camX < 0) { camX = 0};                                  //If camera X is less than 0, it equals 0
        if (camY < 0) { camY = 0};                                  //If camera Y is less than 0, it equals 0
        var firstTileX = Math.floor(camX / this.tileWidth);              //Find first tile to show based on player location
        var firstTileY = Math.floor(camY / this.tileHeight);             //Find first tile to show based on player location
        var offsetX = camX % this.tileWidth;                             //Gives offset (tile shifts by X)
        var offsetY = camY % this.tileHeight;                            //Gives offset (tile shifts by Y)
        var mapEndX = this.canvasXNum;                               //How many tiles to show horizontally
        var mapEndY = this.canvasYNum;                               //How many tiles to show vertically
        for (var y = 0; y <= mapEndY; y++) {
            for (var x = 0; x <= mapEndX; x++) {
                var yC = y + firstTileY, xC = x + firstTileX;       //yC and xC are coordinates plus camera
                if (xC < 0) continue;                               //If xC < 0, no reason to render

                //console.log(this.map.mapArray[yC][xC].v);
                var sprite = this.map.mapArray[yC][xC].v;           //Get sprite based on map location & camera
                var sourceX = (sprite-1) % this.sheetCol * this.tileWidth;
                var sourceY = Math.floor((sprite-1) / this.sheetCol) * this.tileHeight;

                this.drawingSurface.drawImage(
                    this.loadHandler.getImage('img/sprites2.png'),
                    sourceX,
                    sourceY,
                    this.tileWidth,
                    this.tileHeight,
                    x*this.tileWidth - offsetX,
                    y*this.tileHeight - offsetY,
                    this.tileWidth,
                    this.tileHeight
                );

                if (sprite == 1) {
                    let hash = ((yC + xC) ^ xC * 37) % 7 + 1
                    var sourceX = (hash-1) % this.sheetCol * this.tileWidth;
                    var sourceY = Math.floor((hash-1) / this.sheetCol) * this.tileHeight;
                    this.drawingSurface.drawImage(
                        this.loadHandler.getImage('img/sprites2.png'),
                        sourceX,
                        sourceY,
                        this.tileWidth,
                        this.tileHeight,
                        x*this.tileWidth - offsetX,
                        y*this.tileHeight - offsetY,
                        this.tileWidth,
                        this.tileHeight
                    );
                }
            }
        }

        //Draw player
        var len = this.characters.length;
        for (var i = 0; i < len; i++) {
            var character = this.characters[i];

            var characterScreenX = character.x - camX;
            var characterScreenY = character.y - camY;
        
            var spriteNumber = spriteMap[character.sprite][character.action][character.direction][character.frame];
            var sourceX = (spriteNumber) % 10 * 112;
            var sourceY = Math.floor((spriteNumber) / 10) * 112;            
            
            //Draw player   
            var flip = character.direction == "Left" ? -1 : 1;
            var flipOffset = flip == -1 ? -122 : 0;

            if (flip == -1) this.drawingSurface.save();
            if (flip == -1) this.drawingSurface.scale(-1,1);
            this.drawingSurface.drawImage(
                this.loadHandler.getImage('img/sprites-fixedgrid.png'),
                sourceX,
                sourceY,
                112,
                112,
                characterScreenX * flip + flipOffset,
                characterScreenY,
                112,
                112
            );
            if (flip == -1) this.drawingSurface.restore();
        }

        window.requestAnimationFrame(() => this.render());
    }
}