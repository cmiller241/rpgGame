// view.js
//
// Camera zoom and getting the finished frame onto the window.
//
// The game renders at a small "game view" size (window.width x
// window.height, in art pixels), which is then scaled up to fill the
// window. For crisp pixel art that scale should be a whole number, so every
// art pixel becomes an exact square of screen pixels. So:
//
//   * Zoom comes in whole-number levels (Z = zoom in, X = zoom out).
//   * At each level the game view is sized so it exactly fills the window:
//     e.g. a 1280x800 window at 2x shows 640x400 art pixels; at 4x, 320x200.
//   * Changing level glides there over `zoomDuration` seconds. During the
//     glide the scene is rendered at the wider of the two levels' view
//     sizes and scaled by an in-between amount using a pixel-art-friendly
//     filter (shaders/pixelScaleShader.glsl), then it lands exactly on the
//     whole-number level.
//
// Canvases are only rebuilt when the game view size actually changes: at
// the start and end of a zoom, or when the window is resized.
//
// (In the browser, the "window" is the page, measured in real screen
// pixels — see love.boot's screenUnits — so whole-number zoom stays
// pixel-perfect on high-DPI screens too.)

import love from '../love/index.js';
import camera from './camera.js';
import canvas from './canvas.js';
import shader from './shader.js';
import window from './window.js';

const view = {};
export default view;

view.zoom         = 2;       // target zoom level (whole number)
view.displayZoom  = 2;       // zoom currently on screen (in between while gliding)
view.minZoom      = 1;
view.zoomDuration = 0.2;     // seconds per zoom step

// Smallest game view we'll allow, in art pixels. Caps the max zoom so you
// can always see a reasonable area.
view.minViewWidth = 240;
view.minViewHeight = 160;

let zoomFrom = 2, zoomT = 1;  // glide start value and progress (0..1)

function smoothstep(x) {
  return x * x * (3 - 2 * x);
}

// Largest zoom level that keeps the view at least minViewWidth x minViewHeight.
view.maxZoom = function (appW, appH) {
  return Math.max(this.minZoom,
    Math.floor(Math.min(appW / this.minViewWidth, appH / this.minViewHeight)));
};

// Game view size (art px) that fills an appW x appH window at a whole-number
// zoom: [w, h]. Rounded up (so there's no gap at the edges) and to even
// numbers (so the player stays exactly centred).
view.sizeFor = function (zoom, appW, appH) {
  const w = Math.ceil(appW / zoom);
  const h = Math.ceil(appH / zoom);
  return [w + w % 2, h + h % 2];
};

// Makes window.width/height (and the canvases) match what we need to render.
// While gliding, that's the more zoomed-out of the two levels involved.
view.apply = function (appW, appH) {
  const renderZoom = Math.max(this.minZoom, Math.floor(Math.min(this.displayZoom, this.zoom) + 1e-6));
  const [w, h] = this.sizeFor(renderZoom, appW, appH);
  if (w !== window.width || h !== window.height) {
    // Keep the same world point in the middle of the screen, so the
    // camera doesn't drift when the view size jumps.
    camera.x = camera.x + (window.width - w) / 2;
    camera.y = camera.y + (window.height - h) / 2;
    window.width = w;
    window.height = h;
    canvas.initialize(w, h);
  }
};

// Zoom in (+1) or out (-1) one level.
view.step = function (delta, appW, appH) {
  const target = Math.max(this.minZoom, Math.min(this.maxZoom(appW, appH), this.zoom + delta));
  if (target !== this.zoom) {
    zoomFrom = this.displayZoom;
    zoomT = 0;
    this.zoom = target;
  }
};

// Advances the zoom glide. Call every frame (variable dt) before drawing.
view.update = function (dt, appW, appH) {
  if (zoomT < 1) {
    zoomT = Math.min(1, zoomT + dt / this.zoomDuration);
    this.displayZoom = zoomFrom + (this.zoom - zoomFrom) * smoothstep(zoomT);
  } else {
    this.displayZoom = this.zoom;
  }
  this.apply(appW, appH);
};

// Window resized: keep the zoom level valid and refit the view.
view.resize = function (appW, appH) {
  this.zoom = Math.min(this.zoom, this.maxZoom(appW, appH));
  this.displayZoom = this.zoom;
  zoomT = 1;
  this.apply(appW, appH);
};

// Draws canvas.intermediate to the window, scaled and centred.
view.present = function (appW, appH) {
  const s = this.displayZoom;
  let x = (appW - window.width * s) / 2;
  let y = (appH - window.height * s) / 2;
  if (s === Math.floor(s)) {
    // Whole-number zoom: snap to whole screen pixels so art pixels line
    // up exactly with screen pixels.
    x = Math.floor(x);
    y = Math.floor(y);
  }

  const ps = shader.pixelScale;
  love.graphics.setCanvas();
  love.graphics.setShader(ps);
  ps.send('texSize', [window.width, window.height]);
  ps.send('scale', s);
  love.graphics.draw(canvas.intermediate, x, y, 0, s, s);
  love.graphics.setShader();
};
