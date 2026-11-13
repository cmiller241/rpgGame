const KEY_UP = 38;
const KEY_DOWN = 40;
const KEY_LEFT = 37;
const KEY_RIGHT = 39;
const KEY_SPACE = 32;
const KEY_W = 87;
const KEY_D = 68;
const KEY_1 = 49;
const KEY_2 = 50;
const KEY_3 = 51;

class KeyboardState {
    constructor() {
        this.keys = {}

        document.addEventListener("keydown", this.keyDownHandler.bind(this));
        document.addEventListener("keyup", this.keyUpHandler.bind(this));
    }

    keyDownHandler(event) {
        this.keys[event.code] = true;
    }

    keyUpHandler(event) {
        this.keys[event.code] = false;
    }

    isDown(keyCode) {
        return this.keys[keyCode] || false;
    }
}