// camera.js
//
// Follows the player with a slight smoothing lag, and stops at the edges of
// the map so you never see past them.
//
// camera.x / camera.y are the world position of the game view's top-left
// pixel. They're kept as decimals for smooth motion; camera.get() returns
// them rounded to whole pixels for drawing (pixel art must sit on whole
// pixels, or it shimmers).

import player from './player.js';
import sprites from './sprites.js';
import terrain from './terrain.js';
import window from './window.js';

const camera = {};
export default camera;

camera.x = 0;
camera.y = 0;

// How quickly the camera catches up with the player. Higher = tighter.
// 0 = locked exactly to the player with no smoothing.
camera.smoothing = 12;

let initialised = false;

// Where the camera would like to be: player centred in the view.
function target() {
  return [player.drawX + 16 - window.width / 2,
          player.drawY - window.height / 2];
}

// Keeps the view inside the map. If the map is smaller than the view along
// an axis, centre the map on that axis instead.
function clamp(x, y) {
  const mapW = terrain.cols * sprites.size;
  const mapH = terrain.rows * sprites.size;
  if (mapW <= window.width) {
    x = (mapW - window.width) / 2;
  } else {
    x = Math.max(0, Math.min(x, mapW - window.width));
  }
  if (mapH <= window.height) {
    y = (mapH - window.height) / 2;
  } else {
    y = Math.max(0, Math.min(y, mapH - window.height));
  }
  return [x, y];
}

// Call once per frame (variable dt) after the player's draw position is set.
camera.update = function (dt) {
  const [tx, ty] = target();
  if (!initialised || this.smoothing <= 0) {
    this.x = tx;
    this.y = ty;
    initialised = true;
  } else {
    // Frame-rate independent exponential follow.
    const k = 1 - Math.exp(-this.smoothing * dt);
    this.x = this.x + (tx - this.x) * k;
    this.y = this.y + (ty - this.y) * k;
  }
  [this.x, this.y] = clamp(this.x, this.y);
};

// Jump straight to the player (e.g. after teleporting or changing zoom).
camera.snap = function () {
  [this.x, this.y] = clamp(...target());
};

// Whole-pixel camera position for drawing: [x, y].
camera.get = function () {
  return [Math.floor(this.x + 0.5), Math.floor(this.y + 0.5)];
};
