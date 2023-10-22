const keyBoardState = new KeyboardState();
const map = new Map(10,10,'maps/map01.js');

class Game {
    constructor(canvas) {
        this.canvas = canvas;
        this.drawingSurface = this.canvas.getContext("2d");
        this.drawingSurface.imageSmoothingEnabled = false;
        this.drawingSurface.mozImageSmoothingEnabled = false;
        this.drawingSurface.webkitIMageSmoothingEnabled = false;
        this.loadHandler = new LoadHandler();
    }

    start() {
        this.loadHandler.loadAllImages([
            {src: 'img/sprites2.png'},
            {src: 'img/herosprite2.png'},
            {src: 'img/leaf4.png'},
            {src: 'img/treesprite2.png'},
            {src: 'img/grass.png'},
            {src: 'img/ui.png'},
            {src: 'img/lanternlight.png'},
            {src: 'img/chicken.png'}
        ]).then(() => {
            map.load();
            this.update();
        }).catch((error) => {
            console.error('Error loading images:', error);
        });
    }

    update() {
        this.render();
        window.requestAnimationFrame(() => 
        this.update());
    }

    render() {
        this.drawingSurface.drawImage(this.loadHandler.getImage('img/herosprite2.png'),0,0,32,64,10,10,32,64);
    }
}