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
        this.loadHandler = new LoadHandler();
        this.map = new Map(100,100,'maps/map01.js');
    }

    start() {
        const resizeCanvas = () => {
            const contentWidth = window.innerWidth;
            const contentHeight = window.innerHeight;
            this.canvas.width = this.fixedWidth;
            this.canvas.height = this.fixedHeight;
            this.canvasXNum = Math.floor(this.canvas.width / this.tileWidth);
            this.canvasYNum = Math.floor(this.canvas.height / this.tileHeight);
            if (contentWidth > contentHeight) {
                this.canvas.style.width = "100%";
                this.canvas.style.height = "auto";
            } else {
                this.canvas.style.width="auto";
                this.canvas.style.height = "100%";
            }
        };
        resizeCanvas();
        window.addEventListener('resize', resizeCanvas);

        Promise.all([
            this.map.load(),
            this.loadHandler.loadAllImages([
                {src: 'img/sprites2.png'},
                {src: 'img/herosprite2.png'},
                {src: 'img/leaf4.png'},
                {src: 'img/treesprite2.png'},
                {src: 'img/grass.png'},
                {src: 'img/ui.png'},
                {src: 'img/lanternlight.png'},
                {src: 'img/chicken.png'}
           ])
        ]).then(() => {
            console.log("All assets loaded successfully!");
            this.update();
        }).catch((error) => {
            console.log("Error loading assets", error);
        })
    }

    update() {
        this.render();
        window.requestAnimationFrame(() => this.update());
    }

    render() {
        var camX = Math.floor(this.playerX - Math.floor(this.canvas.width/2));     //Camera begins half stage from center of player
        var camY = Math.floor(this.playerY - Math.floor(this.canvas.height/2));     //Camera begins half stage from center of player
        if (camX < 0) { camX = 0};                                  //If camera X is less than 0, it equals 0
        if (camY < 0) { camY = 0};                                  //If camera Y is less than 0, it equals 0
        var firstTileX = Math.floor(camX / this.tileWidth);              //Find first tile to show based on player location
        var firstTileY = Math.floor(camY / this.tileHeight);             //Find first tile to show based on player location
        var offsetX = camX % this.tileWidth;                             //Gives offset (tile shifts by X)
        var offsetY = camY % this.tileHeight;                            //Gives offset (tile shifts by Y)
        var mapEndX = this.canvasXNum + 5;                               //How many tiles to show horizontally
        var mapEndY = this.canvasYNum + 5;                               //How many tiles to show vertically
        for (var y = 0; y <= mapEndY; y++) {
            for (var x = 0; x <= mapEndX; x++) {
                var yC = y + firstTileY;                            //y + camera
                var xC = x + firstTileX;                            //x + camera
                if (xC < 0) continue;                               //If xC < 0, no reason to render

                //console.log(this.map.mapArray[yC][xC].v);
                var sprite = this.map.mapArray[yC][xC].v;           //Get sprite based on map location & camera
                var sourceX = Math.floor((sprite-1) % this.sheetCol) * this.tileWidth;
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
            }
        }
    }
}