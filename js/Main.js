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
        
        //Tree Offscreen Buffer
        this.offScreenCanvas = document.createElement("canvas");
        this.offScreenCanvas.width = '160';
        this.offScreenCanvas.height = '160';
        this.treeSurface = this.offScreenCanvas.getContext("2d");
        this.treeSurface.imageSmoothingEnabled = false;
        this.treeSurface.mozImageSmoothingEnabled = false;
        this.treeSurface.webkitIMageSmoothingEnabled = false;
        this.treeSections = [
            {x:0, y:0, width:5, height:160},
            {x:5, y:0, width:10, height:160},
            {x:15, y:0, width:7, height:160},
            {x:22, y:0, width:8, height:160},
            {x:30, y:0, width:6, height:160},
            {x:36, y:0, width:9, height:160},
            {x:45, y:0, width:7, height:160},
            {x:52, y:0, width:8, height:160},
            {x:60, y:0, width:5, height:160},
            {x:65, y:0, width:10, height:160},
            {x:75, y:0, width:7, height:160},
            {x:82, y:0, width:8, height:160},
            {x:90, y:0, width:6, height:160},
            {x:96, y:0, width:9, height:160},
            {x:105, y:0, width:7, height:160},
            {x:112, y:0, width:8, height:160},
            {x:120, y:0, width:5, height:160},
            {x:125, y:0, width:10, height:160},
            {x:135, y:0, width:7, height:160},
            {x:142, y:0, width:18, height:160}
        ];
        this.treeTime = 0;
        this.treeAnimationDuration = 2000;
        this.treeAmplitude = -.2;
        this.treeSway = .5;

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
                {src: 'img/tree.png'},
                {src: 'img/grass.png'},
                {src: 'img/ui.png'},
                {src: 'img/lanternlight.png'},
                {src: 'img/chicken.png'},
                {src: 'img/grunge2.jpg'}
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

        //setTimeout(this.update(), 20);

        this.characters.forEach(character => character.update()); //Update all characters' frames

        //Player movement
        this.characters[0].action = "Standing";
        if (keyBoardState.isDown("ArrowLeft")) {
            this.characters[0].x -= 5;
            this.characters[0].direction = "Left";
            this.characters[0].action= "Walking";
        } 
        if (keyBoardState.isDown("ArrowRight")) {
            this.characters[0].x += 5;
            this.characters[0].direction = "Right";
            this.characters[0].action = "Walking";
        } 
        if (keyBoardState.isDown("ArrowUp")) {
            this.characters[0].y -= 5;
            this.characters[0].direction = "Up";
            this.characters[0].action= "Walking";
        } 
        if (keyBoardState.isDown("ArrowDown")) {
            this.characters[0].y += 5;
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
 
        this.render();
        
        window.requestAnimationFrame(() => this.update());
 
        //console.log("The playerX is " + this.playerX + " and the playerY is " + this.playerY);

    }

    moveLeaves() {
        this.treeSurface.clearRect(0,0,this.offScreenCanvas.width,this.offScreenCanvas.height);
        const scalingFactors = this.treeSections.map((section,index) => 
        {
            const scaleFactor = this.treeAmplitude * Math.sin(2*Math.PI * (index / this.treeSections.length) - (this.treeTime / this.treeAnimationDuration * 2 * Math.PI));
            return section.width + scaleFactor;
        });

            let currentX = 0;
            const sectionPositions = scalingFactors.map((scaleFactor, index) =>
            {
                const x = currentX;
                currentX += scaleFactor;
                return {x:x, width:scaleFactor};
            });
            sectionPositions.forEach((section, index) => {
                const sectionToDraw = this.treeSections[index];
                this.treeSurface.drawImage(
                    this.loadHandler.getImage('img/tree.png'), 
                    160 + sectionToDraw.x, 
                    sectionToDraw.y, 
                    section.width, 
                    sectionToDraw.height, 
                    section.x, 
                    sectionToDraw.y, 
                    section.width, 
                    sectionToDraw.height
                );
            });

            this.treeTime = (this.treeTime + 16) % this.treeAnimationDuration;
    }


    render() {
        this.moveLeaves();

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
            for (var x = -2; x <= mapEndX; x++) {
                var yC = y + firstTileY, xC = x + firstTileX;       //yC and xC are coordinates plus camera
                if (xC < 0) continue;                               //If xC < 0, no reason to render

            
                var sprite = this.map.mapArray[yC][xC].v;           //Get sprite based on map location & camera
                if (sprite == sprite) {
                    var fakeSprite = 1;
                    var sourceX = (fakeSprite-1) % this.sheetCol * this.tileWidth;
                    var sourceY = Math.floor((fakeSprite-1) / this.sheetCol) * this.tileHeight;

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

                if (sprite == 512) { 

                // Translate to the center of the tree
                this.drawingSurface.translate((x*this.tileWidth - offsetX - 64) + 160/2, (y*this.tileHeight - offsetY - 192) + 224);

                // Rotate the context
                let rotationAngle = Math.sin((this.treeTime + Math.cos(x*10) * Math.sin(y*10)) / this.treeAnimationDuration * 2 * Math.PI) * this.treeSway;
                this.drawingSurface.rotate(rotationAngle * Math.PI / 180);

                // Draw the image, but adjust the x and y coordinates because we've translated the context
                this.drawingSurface.drawImage (
                    this.loadHandler.getImage('img/tree.png'),
                    0,
                    0,
                    160,
                    224,
                    -160/2,
                    -224,
                    160,
                    224
                );

                // Restore the context to its original state
                //this.drawingSurface.setTransform(1, 0, 0, 1, 0, 0);

                    // this.drawingSurface.drawImage (
                    //     this.loadHandler.getImage('img/tree.png'),
                    //     0,
                    //     0,
                    //     160,
                    //     224,
                    //     x*this.tileWidth - offsetX - 64,
                    //     y*this.tileHeight - offsetY - 192,
                    //     160,
                    //     224
                    // );

                    //Create code to change the hue of the drawImage directly below to something random
                    let hash = (((yC + xC) ^ xC * 37) % 7 + 1)*5;
                    this.drawingSurface.filter = `hue-rotate(${hash}deg)`;
                    this.drawingSurface.drawImage(
                        this.offScreenCanvas,
                        0,
                        0,
                        160,
                        160,
                        -160/2,//x*this.tileWidth - offsetX - 64,
                        -224,//y*this.tileHeight - offsetY - 192,
                        160,
                        160
                    );  
                    this.drawingSurface.filter = 'none';
                    this.drawingSurface.setTransform(1,0,0,1,0,0);
                    //this.drawingSurface.restore();
                }
            }
        }

        //Grunge overlay for that certain something extra
        this.drawingSurface.globalCompositeOperation = "multiply";
        this.drawingSurface.globalAlpha = 0.7;
        this.drawingSurface.drawImage(
            this.loadHandler.getImage('img/grunge2.jpg'),
            0,
            0,
            2227,
            1133,
            0,
            0,
            this.canvas.width/2,
            this.canvas.height/2
        );
        this.drawingSurface.globalAlpha = 1;
        this.drawingSurface.globalCompositeOperation = "source-over";


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

        //window.requestAnimationFrame(() => this.render());
    }
}