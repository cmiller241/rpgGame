const keyBoardState = new KeyboardState();

class Game {
    constructor() {
        this.canvas = document.createElement('canvas');
        document.body.appendChild(this.canvas);
        this.canvas.width = window.innerWidth;
        this.canvas.height = window.innerHeight;
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
        this.treeOffScreenCanvas = document.createElement("canvas");
        this.treeOffScreenCanvas.width = '160';
        this.treeOffScreenCanvas.height = '160';
        this.treeSurface = this.treeOffScreenCanvas.getContext("2d");
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
        this.treeAnimationDuration = 900;
        this.treeAmplitude = .3;
        this.treeSway = .5;

        //Ground Buffer
        this.groundOffScreenCanvas = document.createElement("canvas");
        this.groundOffScreenCanvas.width = this.canvas.width;
        this.groundOffScreenCanvas.height = this.canvas.height;
        this.groundScreenCtx = this.groundOffScreenCanvas.getContext("2d");

        //Shadow Screen Buffer
        this.shadowOffScreenCanvas = document.createElement("canvas");
        this.shadowOffScreenCanvas.width = this.canvas.width;
        this.shadowOffScreenCanvas.height = this.canvas.height;
        this.shadowScreenCtx = this.shadowOffScreenCanvas.getContext("2d");

        //Object Buffer
        this.objectOffScreenCanvas = document.createElement("canvas");
        this.objectOffScreenCanvas.width = this.canvas.width;
        this.objectOffScreenCanvas.height = this.canvas.height;
        this.objectScreenCtx = this.objectOffScreenCanvas.getContext("2d");

        //Silhouette Buffer
        this.silhouetteOffScreenCanvas = document.createElement("canvas");
        this.silhouetteOffScreenCanvas.width = this.canvas.width;
        this.silhouetteOffScreenCanvas.height = this.canvas.height;
        this.silhouetteScreenCtx = this.silhouetteOffScreenCanvas.getContext("2d");

        //Offscreen Buffer
        this.offscreenCanvas = document.createElement("canvas");
        this.offscreenCanvas.width = this.canvas.width;
        this.offscreenCanvas.height = this.canvas.height;
        this.offscreenCtx = this.offscreenCanvas.getContext("2d");

        //Shadow for Particular Object Buffer
        this.shadowBufferTemplateCanvas = document.createElement("canvas"); 
        this.shadowBufferTemplateCanvas.width = 96;
        this.shadowBufferTemplateCanvas.height = 96;
        this.shadowBufferTemplateCtx = this.shadowBufferTemplateCanvas.getContext("2d");

        //Shadow for Particular Object Buffer
        this.shadowBufferFinalCanvas = document.createElement("canvas"); 
        this.shadowBufferFinalCanvas.width = 96;
        this.shadowBufferFinalCanvas.height = 96;
        this.shadowBufferFinalCtx = this.shadowBufferFinalCanvas.getContext("2d");

        //Bind resizeCanvas method to this instance (so "this" doesn't putz out)
        this.resizeCanvas = this.resizeCanvas.bind(this);

        //Shadow
        this.lightSource = {x: 200, y: -2000, size: -32};  

        this.characters = [];
        this.characters[0] = new Character(0,0,100,32,64);
        //this.characters[1] = new Character(1,200,400,32,64);
    }

    resizeCanvas() {

        this.canvas.width = window.innerWidth;

        this.canvas.style.width = Math.floor(this.scale*100) + "%";
        
        this.canvas.height = window.innerHeight;

        this.canvasXNum = Math.floor(this.canvas.width / this.tileWidth);
        this.canvasYNum = Math.floor(this.canvas.height / this.tileHeight);

        //this.offScreenCanvas.width = 500;//this.canvas.width;
        //this.offScreenCanvas.height = 600;//this.canvas.height;
    }

    start() {
        this.resizeCanvas();
        this.putShadowsOnTemplate();
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

        this.characters.forEach(character => character.update()); //Update all characters' frames

        const player = this.characters[0];

        //Player movement
        this.characters[0].action = "Standing";
        if (keyBoardState.isDown("ArrowLeft")) {
            player.x -= 5;
            player.direction = "Left";
            player.action= "Walking";
        } 
        if (keyBoardState.isDown("ArrowRight")) {
            player.x += 5;
            player.direction = "Right";
            player.action = "Walking";
        } 
        if (keyBoardState.isDown("ArrowUp")) {
            player.y -= 5;
            player.direction = "Up";
            player.action= "Walking";
        } 
        if (keyBoardState.isDown("ArrowDown")) {
            player.y += 5;
            player.direction = "Down";
            player.action= "Walking";
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
        if (keyBoardState.isDown("KeyT")) {
            this.lightSource.y -= 20;
            this.putShadowsOnTemplate();
        }
        if (keyBoardState.isDown("KeyY")) {
            this.lightSource.y += 20;
            this.putShadowsOnTemplate();
        }   
        if (keyBoardState.isDown("KeyH")) {
            this.lightSource.x += 20;
            this.putShadowsOnTemplate();
        }
        if (keyBoardState.isDown("KeyG")) {
            this.lightSource.x -= 20;
            this.putShadowsOnTemplate();
        }
        if (keyBoardState.isDown("KeyJ")) {
            this.lightSource.size -= 1;
            this.putShadowsOnTemplate();
        }
        if (keyBoardState.isDown("KeyF")) {
            this.lightSource.size += 1;
            this.putShadowsOnTemplate();
        }
 
        this.render();
        
        window.requestAnimationFrame(() => this.update());

    }

    moveLeaves() {
        this.treeSurface.clearRect(0,0,this.treeOffScreenCanvas.width,this.treeOffScreenCanvas.height);
        const twoPi = 2 * Math.PI;
        const lengthFactor = twoPi / this.treeSections.length;
        const timeFactor = this.treeTime / this.treeAnimationDuration * twoPi;
        const treeImage = this.loadHandler.getImage('img/tree.png');

        let currentX = 0;

        this.treeSections.forEach((section, index) => {
            const scaleFactor = this.treeAmplitude * Math.sin(lengthFactor * index - timeFactor);   
            const width = section.width + scaleFactor;
            const x = currentX;
            currentX += width;

            this.treeSurface.drawImage(
                treeImage,
                160 + section.x,
                section.y,
                section.width,
                section.height,
                x,
                section.y,
                width,
                section.height
            );
        });

        this.treeTime = (this.treeTime + 16) % this.treeAnimationDuration;
    }

    putShadowsOnTemplate() {

        console.log("lightSource.x is " + this.lightSource.x + " and lightSource.y is " + this.lightSource.y + " and lightSource.size is " + this.lightSource.size);
        this.shadowBufferTemplateCtx.clearRect(0,0,this.shadowBufferTemplateCanvas.width,this.shadowBufferTemplateCanvas.height);

        let angle = Math.atan2(
            this.lightSource.y - 64, 
            this.lightSource.x - 64
        );
        
        let br = {x: 64, y: 64};
        let bl = {x: 32, y: 64};
        let tr = {x: 64, y: 32};
        let tl = {x: 32, y: 32};

        let sbr = {x: br.x + this.lightSource.size * Math.cos(angle), y: br.y + this.lightSource.size * Math.sin(angle)};
        let sbl = {x: bl.x + this.lightSource.size * Math.cos(angle), y: bl.y + this.lightSource.size * Math.sin(angle)};
        let str = {x: tr.x + this.lightSource.size * Math.cos(angle), y: tr.y + this.lightSource.size * Math.sin(angle)};
        let stl = {x: tl.x + this.lightSource.size * Math.cos(angle), y: tl.y + this.lightSource.size * Math.sin(angle)};

        this.shadowBufferTemplateCtx.beginPath();

        if (sbr.x < br.x && sbr.y < br.y) {
            this.shadowBufferTemplateCtx.moveTo(sbl.x, sbl.y);
            this.shadowBufferTemplateCtx.lineTo(stl.x, stl.y);
            this.shadowBufferTemplateCtx.lineTo(str.x, str.y);
            this.shadowBufferTemplateCtx.lineTo(tr.x,tr.y);
            this.shadowBufferTemplateCtx.lineTo(tl.x,br.y);
            this.shadowBufferTemplateCtx.lineTo(bl.x,bl.y);
        } else if (sbr.x > br.x && sbr.y < br.y) {
            this.shadowBufferTemplateCtx.moveTo(sbr.x, sbr.y);
            this.shadowBufferTemplateCtx.lineTo(str.x, str.y);
            this.shadowBufferTemplateCtx.lineTo(stl.x, stl.y);
            this.shadowBufferTemplateCtx.lineTo(tl.x,tl.y);
            this.shadowBufferTemplateCtx.lineTo(tr.x,bl.y);
            this.shadowBufferTemplateCtx.lineTo(br.x,br.y);
        } else if (sbr.x < br.x && sbr.y > br.y) {
            this.shadowBufferTemplateCtx.moveTo(sbr.x, sbr.y);
            this.shadowBufferTemplateCtx.lineTo(sbl.x, sbl.y);
            this.shadowBufferTemplateCtx.lineTo(stl.x,stl.y);
            this.shadowBufferTemplateCtx.lineTo(tl.x,tl.y);
            this.shadowBufferTemplateCtx.lineTo(bl.x,tr.y);
            this.shadowBufferTemplateCtx.lineTo(br.x,br.y);
        } else if (sbr.x > br.x && sbr.y > br.y) {
            this.shadowBufferTemplateCtx.moveTo(sbr.x, sbr.y);
            this.shadowBufferTemplateCtx.lineTo(sbl.x, sbl.y);
            this.shadowBufferTemplateCtx.lineTo(bl.x,bl.y);
            this.shadowBufferTemplateCtx.lineTo(br.x, br.y);
            this.shadowBufferTemplateCtx.lineTo(tr.x,tr.y);
            this.shadowBufferTemplateCtx.lineTo(str.x,str.y);
        }
        this.shadowBufferTemplateCtx.closePath();

        this.shadowBufferTemplateCtx.fillStyle = "rgba(0,0,0,1)";
        this.shadowBufferTemplateCtx.fill();

    }

    render() {
        this.moveLeaves();
        // Clear the ground offscreen canvas
        this.groundScreenCtx.clearRect(0, 0, this.groundOffScreenCanvas.width, this.groundOffScreenCanvas.height);
        this.shadowScreenCtx.clearRect(0, 0, this.shadowOffScreenCanvas.width, this.shadowOffScreenCanvas.height);
        this.objectScreenCtx.clearRect(0, 0, this.objectOffScreenCanvas.width, this.objectOffScreenCanvas.height);
        // this.silhouetteScreenCtx.clearRect(0, 0, this.silhouetteOffScreenCanvas.width, this.silhouetteOffScreenCanvas.height);

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
        for (var y = -2; y <= mapEndY; y++) {
            var yC = y + firstTileY;
            if (yC < 0) continue;
            for (var x = -2; x <= mapEndX; x++) {
                var xC = x + firstTileX;                            //yC and xC are coordinates plus camera
                if (xC < 0) continue;                               //If xC < 0, no reason to render

                var z = this.map.mapArray[yC][xC].z;
                var sprite = this.map.mapArray[yC][xC].v;           //Get sprite based on map location & camera

                var isLowerAdjacentTile = false;

                for (var outY = -1; outY <= 1; outY++) {
                    for (var outX = -1; outX <= 1; outX++) {
                        if (outY === 0 && outX === 0) continue;
                        if (yC + outY < 0 || yC + outY >= this.map.mapArray.length || xC + outX < 0 || xC + outX >= this.map.mapArray[0].length) {
                            continue;
                        }
                        if (this.map.mapArray[yC + outY][xC + outX].z > z) {
                            isLowerAdjacentTile = true;
                            break;
                        }
                        if (isLowerAdjacentTile) break;
                    }
                }

                if (isLowerAdjacentTile) {              //If ground is elevated, we need to delete what may be on object screen (trees/characters/etc).
                    this.shadowBufferFinalCtx.clearRect(0, 0, 96, 96);
                    this.shadowBufferFinalCtx.drawImage(
                        this.shadowBufferTemplateCanvas,
                        0,
                        0,
                        96,
                        96,
                        0,
                        0,
                        96,
                        96
                    )

                    if (this.map.mapArray[yC-1][xC-1].z <= z) this.shadowBufferFinalCtx.clearRect(0, 0, 32, 32);
                    if (this.map.mapArray[yC-1][xC].z <= z) this.shadowBufferFinalCtx.clearRect(32, 0, 32, 32);
                    if (this.map.mapArray[yC-1][xC+1].z <= z) this.shadowBufferFinalCtx.clearRect(64, 0, 32, 32);
                    if (this.map.mapArray[yC][xC-1].z <= z) this.shadowBufferFinalCtx.clearRect(0, 32, 32, 32);
                    this.shadowBufferFinalCtx.clearRect(32, 32, 32, 32);
                    if (this.map.mapArray[yC][xC+1].z <= z) this.shadowBufferFinalCtx.clearRect(64, 32, 32, 32);
                    if (this.map.mapArray[yC+1][xC-1].z <= z) this.shadowBufferFinalCtx.clearRect(0, 64, 32, 32);
                    if (this.map.mapArray[yC+1][xC].z <= z) this.shadowBufferFinalCtx.clearRect(32, 64, 32, 32);
                    if (this.map.mapArray[yC+1][xC+1].z <= z) this.shadowBufferFinalCtx.clearRect(64, 64, 32, 32);

                    //If adjacent sprites both 1 level high, the shadow will extend into grass to the left. Weird anamoly.
                    //The below line deletes it. 
                    if (this.map.mapArray[yC][xC-1].z == z && z < 0) this.shadowBufferFinalCtx.clearRect(0,0,32,32); 
                    
                    this.shadowScreenCtx.drawImage(
                        this.shadowBufferFinalCanvas,
                        0,
                        0,
                        96,
                        96,
                        x*this.tileWidth - offsetX - 32,
                        y*this.tileHeight - offsetY - 32,
                        96,
                        96
                    );

                    // this.shadowScreenCtx.drawImage(
                    //     this.shadowBufferTemplateCanvas,
                    //     0,
                    //     0,
                    //     96,
                    //     96,
                    //     200,
                    //     200,
                    //     96,
                    //     96
                    // );
                }



                if (sprite == 1 || sprite == 10 || sprite == 512) {
                    let hash = 1;//((yC + xC) ^ xC * 37) % 7 + 1;

                    //Bitwising Time!
                    if (yC > 1 && -this.map.mapArray[yC-1][xC].z >= -z) hash = hash + 1;
                    if (-this.map.mapArray[yC][xC + 1].z >= -z) hash = hash + 2;
                    if (xC > 1 && -this.map.mapArray[yC][xC-1].z >= -z) hash = hash + 4;

                    var sourceX = (hash-1) % this.sheetCol * this.tileWidth;
                    var sourceY = Math.floor((hash-1) / this.sheetCol) * this.tileHeight;

                    var color;
                    
                    this.groundScreenCtx.drawImage(
                        this.loadHandler.getImage('img/sprites2.png'),
                        sourceX,
                        sourceY,
                        this.tileWidth,
                        this.tileHeight,
                        x*this.tileWidth - offsetX,
                        y*this.tileHeight + z - offsetY,
                        this.tileWidth,
                        this.tileHeight
                    );

                    if (z < 0) {
                        color = "rgba(255,255,255," + Math.abs(z) / 128 * 0.2 + ")";
                    } else if (z > 0) {
                        color = "rgba(0,0,0," + Math.abs(z) / 128 * 0.2 + ")"; 
                    } else {
                        color = null;
                    }

                    if (color) {
                        this.groundScreenCtx.fillStyle = color;
                        this.groundScreenCtx.fillRect(
                            x*this.tileWidth - offsetX,
                            y*this.tileHeight + z - offsetY,
                            this.tileWidth,
                            this.tileHeight
                        );
                    }

                    if (this.map.mapArray[yC][xC].z < 0) {          //If ground is elevated, we need to delete what may be on object screen (trees/characters/etc).
                        this.objectScreenCtx.clearRect(
                            x*this.tileWidth - offsetX,
                            y*this.tileHeight + this.map.mapArray[yC][xC].z - offsetY,
                            this.tileWidth,
                            this.tileHeight
                        );
                        this.shadowScreenCtx.clearRect(
                            x*this.tileWidth - offsetX,
                            y*this.tileHeight + this.map.mapArray[yC][xC].z - offsetY,
                            this.tileWidth,
                            this.tileHeight
                        );
                    }
                }

                if (sprite == 1) {
                    let hash = ((yC + xC) ^ xC * 37) % 7 + 11;
                    var sourceX = (hash-1) % this.sheetCol * this.tileWidth;
                    var sourceY = Math.floor((hash-1) / this.sheetCol) * this.tileHeight;
                    this.groundScreenCtx.drawImage(
                        this.loadHandler.getImage('img/sprites2.png'),
                        sourceX,
                        sourceY,
                        this.tileWidth,
                        this.tileHeight,
                        x*this.tileWidth - offsetX,
                        y*this.tileHeight + z - offsetY,
                        this.tileWidth,
                        this.tileHeight
                    );
                }
                


                if (yC - 1 < 1) continue;
                sprite = this.map.mapArray[yC-1][xC].v;
                if (sprite == 10) {                                                 //Grass Tile
                    var sourceX = (sprite-1) % this.sheetCol * this.tileWidth;
                    var sourceY = Math.floor((sprite-1) / this.sheetCol) * this.tileHeight;
                    var rotationAngle = Math.sin((this.treeTime + x*y) / this.treeAnimationDuration * 2 * Math.PI) * this.treeSway;
                    var grassFrame = (rotationAngle < 0) ? 1 : 0;
                    this.objectScreenCtx.drawImage(
                        this.loadHandler.getImage('img/grass.png'),
                        128,
                        0 + grassFrame * 27,
                        32,
                        27,
                        x*this.tileWidth - offsetX,
                        (y-1)*this.tileHeight - 20 - offsetY,
                        32,
                        27
                    );
                    this.objectScreenCtx.drawImage(
                        this.loadHandler.getImage('img/grass.png'),
                        128,
                        0 + (1 - grassFrame) * 27,
                        32,
                        27,
                        x*this.tileWidth + 8 - offsetX,
                        (y-1)*this.tileHeight - 5 - offsetY,
                        32,
                        27
                    );
                }

                if (this.map.mapArray[yC][xC].z != 0) {                                     //Mountain Tile for z-index tiles
                    var zHeight = -this.map.mapArray[yC][xC].z/this.tileHeight;                  //Mountain = negative; valley = positive. Multiplied by -1: Mountain = positive; valley = negative
                    var currZ = this.map.mapArray[yC][xC].z;

                    if (this.map.mapArray[yC-1][xC].z < this.map.mapArray[yC][xC].z && zHeight < 0) {  //Only creates wall for a valley if the coordinate above is higher :-)
                        for(var i = 0; i>zHeight;i--) {             //Valley       
                            var mSprite = 23;
                            var sourceX = (mSprite-1) % this.sheetCol * this.tileWidth;
                            var sourceY = Math.floor((mSprite-1) / this.sheetCol) * this.tileHeight;
                            
                            this.objectScreenCtx.drawImage(                         
                                this.loadHandler.getImage('img/sprites2.png'),
                                sourceX,
                                sourceY,
                                this.tileWidth,
                                this.tileHeight,
                                x*this.tileWidth - offsetX,
                                y*this.tileHeight - i*this.tileHeight - offsetY,
                                this.tileWidth,
                                this.tileHeight
                            );        
                        }
                        
                        var gradient = this.objectScreenCtx.createLinearGradient(
                            x*this.tileWidth - offsetX,
                            y*this.tileHeight - zHeight*this.tileHeight - offsetY,
                            x*this.tileWidth - offsetX,
                            y*this.tileHeight - offsetY
                        );

                        gradient.addColorStop(.2, "rgba(0,0,0,0.4)");
                        gradient.addColorStop(.5, "rgba(0,0,0,.3)");
                        gradient.addColorStop(1, "rgba(0,0,0,.1)");

                        this.objectScreenCtx.save();

                        this.objectScreenCtx.fillStyle = gradient;

                        this.objectScreenCtx.fillRect(
                            x*this.tileWidth - offsetX,
                            y*this.tileHeight - zHeight*this.tileHeight - offsetY,
                            this.tileWidth,
                            zHeight*this.tileHeight
                        );

                        this.objectScreenCtx.restore();
                    }


                    for (var i=0; i<zHeight; i++) {                 //Mountain
                        var mSprite = 23;

                        //Bitwising Time!
                        if (-this.map.mapArray[yC][xC+1].z / this.tileHeight > i) mSprite = mSprite + 1;
                        if (-this.map.mapArray[yC][xC-1].z / this.tileHeight > i) mSprite = mSprite + 2;
                        if (zHeight > 1) mSprite = mSprite + 4;
                        if (i != 0 && i != zHeight) mSprite = mSprite + 4;
                        if (i == zHeight-1 && i != 0) {
                            mSprite = mSprite + 4;
                        }

                        var sourceX = (mSprite-1) % this.sheetCol * this.tileWidth;
                        var sourceY = Math.floor((mSprite-1) / this.sheetCol) * this.tileHeight;

                        this.objectScreenCtx.drawImage(
                            this.loadHandler.getImage('img/sprites2.png'),
                            sourceX,
                            sourceY,
                            this.tileWidth,
                            this.tileHeight,
                            x*this.tileWidth - offsetX,
                            y*this.tileHeight - i*this.tileHeight - offsetY,
                            this.tileWidth,
                            this.tileHeight
                        );
                    }

                    if (zHeight > 0) {              //Gradient the walls of the mountain
                        var gradient = this.objectScreenCtx.createLinearGradient(
                            x*this.tileWidth - offsetX,
                            y*this.tileHeight - offsetY,
                            x*this.tileWidth - offsetX,
                            y*this.tileHeight - zHeight*this.tileHeight - offsetY
                        );  

                        gradient.addColorStop(.2, "rgba(0,0,0,0.3)");
                        gradient.addColorStop(.5, "rgba(0,0,0,.1)");
                        gradient.addColorStop(.5, "rgba(0,0,0,.1)");
                        gradient.addColorStop(1, "rgba(0,0,0,0)");

                        this.objectScreenCtx.save();

                        this.objectScreenCtx.fillStyle = gradient;

                        this.objectScreenCtx.fillRect(
                            x*this.tileWidth - offsetX,
                            (y+1)*this.tileHeight - offsetY,
                            this.tileWidth,
                            -zHeight*this.tileHeight
                        );

                        this.objectScreenCtx.restore();

                    }

                }


                
                if (sprite == 512) { 

                    let rotationAngle = Math.sin((this.treeTime + Math.cos(x*10) * Math.sin(y*10)) / this.treeAnimationDuration * 2 * Math.PI) * this.treeSway;
                    let xOffset = Math.sin(rotationAngle) * 3;

                    //Tree shadow
                    this.shadowScreenCtx.drawImage (
                        this.loadHandler.getImage('img/tree.png'),
                        160,
                        160,
                        160,
                        64,
                        x*this.tileWidth - offsetX - 64 + xOffset,
                        y*this.tileHeight - offsetY - 32,
                        160,
                        64
                    );

                    // Translate to the center of the tree
                    this.objectScreenCtx.translate((x*this.tileWidth - offsetX - 64) + 160/2, ((y-1)*this.tileHeight - offsetY - 192) + 224);

                    // Rotate the context
                    this.objectScreenCtx.rotate(rotationAngle * Math.PI / 180);

                    // Draw the image, but adjust the x and y coordinates because we've translated the context
                    this.objectScreenCtx.drawImage (
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

                    //Create code to change the hue of the drawImage directly below to something random
                    let hash = (((yC + xC) ^ xC * 37) % 7 + 1)*5;
                    this.objectScreenCtx.filter = `hue-rotate(${hash}deg)`;
                    this.objectScreenCtx.drawImage(
                        this.treeOffScreenCanvas,
                        0,
                        0,
                        160,
                        160,
                        -160/2,//x*this.tileWidth - offsetX - 64,
                        -224,//y*this.tileHeight - offsetY - 192,
                        160,
                        160
                    );  
                    this.objectScreenCtx.filter = 'none';
                    this.objectScreenCtx.setTransform(1,0,0,1,0,0);

                
                }
            
            }

            //Let's plop in some characters (Characters are added after end of row)
            var len = this.characters.length;
            for (var i = 0; i < len; i++) {
                var character = this.characters[i];
                var characterRow = Math.floor(character.y / this.tileHeight);
                if (characterRow != yC) continue; 
    
                var characterScreenX = character.x - camX;
                var characterScreenY = character.y - camY;
            
                var spriteNumber = spriteMap[character.sprite][character.action][character.direction][character.frame];
                var sourceX = (spriteNumber) % 10 * 112;
                var sourceY = Math.floor((spriteNumber) / 10) * 112;            
                
                //Draw player   
                var flip = character.direction == "Left" ? -1 : 1;
                var flipOffset = flip == -1 ? -122 : 0;
    
                if (flip == -1) {
                    this.objectScreenCtx.save();
                    this.objectScreenCtx.scale(-1,1);
                    // this.silhouetteScreenCtx.save();
                    // this.silhouetteScreenCtx.scale(-1,1);
                }
                this.objectScreenCtx.drawImage(
                    this.loadHandler.getImage('img/sprites-fixedgrid.png'),
                    sourceX,
                    sourceY,
                    112,
                    112,
                    (characterScreenX + character.width/2 - 122/2) * flip + flipOffset,
                    characterScreenY - character.base,
                    112,
                    112
                );

                //Draw silhouette
                // this.silhouetteScreenCtx.drawImage(
                //     this.loadHandler.getImage('img/sprites-fixedgrid.png'),
                //     sourceX,
                //     sourceY,
                //     112,
                //     112,
                //     (characterScreenX + character.width/2 - 122/2) * flip + flipOffset,
                //     characterScreenY - character.base,
                //     112,
                //     112
                // );


                if (flip == -1) {
                    this.objectScreenCtx.restore();
                    // this.silhouetteScreenCtx.restore();
                }
            }
    


        }

        //// Draws the silhouette down.  
        // this.objectScreenCtx.globalAlpha = 0.3;
        // this.objectScreenCtx.drawImage(
        //      this.silhouetteOffScreenCanvas,
        //      0,
        //      0,
        // );
        // this.objectScreenCtx.globalAlpha = 1;

        // //Grunge overlay for that certain something extra
        this.groundScreenCtx.globalCompositeOperation = "multiply";
        this.groundScreenCtx.globalAlpha = 0.7;
        this.groundScreenCtx.drawImage(
            this.loadHandler.getImage('img/grunge2.jpg'),
            0,
            0,
            2227,
            1133,
            0,
            0,
            this.groundScreenCtx.canvas.width,
            this.groundScreenCtx.canvas.height
        );
        this.groundScreenCtx.globalAlpha = 1;
        this.groundScreenCtx.globalCompositeOperation = "source-over";

        this.offscreenCtx.drawImage(this.groundOffScreenCanvas, 0, 0);
        this.offscreenCtx.globalAlpha = 0.3;
            this.offscreenCtx.drawImage(this.shadowOffScreenCanvas, 0, 0);
        this.offscreenCtx.globalAlpha = 1;
        this.offscreenCtx.drawImage(this.objectOffScreenCanvas, 0, 0);
        this.drawingSurface.drawImage(this.offscreenCanvas, 0, 0);

    }
}