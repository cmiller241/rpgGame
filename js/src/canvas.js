// canvas.js
//
// Off-screen render targets. All are the size of the game view
// (window.width x window.height) except `temp`.
//
//   offscreen     ground tiles (grass, dirt, cliff faces)
//   object        sprites: player, trees, crops, pickups
//   shadow        sprite shadows (R = sun, G = lamp), see spriteShadow.js
//   surface       per-pixel terrain shape (face/top + height), see terrain.js
//   intermediate  the lit, colour-graded frame before it's scaled to the window
//   temp          200x200 scratch space for the player's current frame
//   xray          the player alone, never hidden by anything; where terrain
//                 hides him, the lighting pass draws this as a faint ghost
//   focus         while he's in a pit: just the tiles at or below his level
//   focusSurface  terrain shape (like surface) for just those tiles

import love from '../love/index.js';

const canvas = {};
export default canvas;

const NAMES = ['object', 'shadow', 'offscreen', 'intermediate', 'temp', 'xray', 'surface', 'focus', 'focusSurface'];

canvas.initialize = function (cWidth, cHeight) {
  // (LÖVE frees old canvases when they're garbage collected; WebGL needs
  // it done by hand, or every resize/zoom leaks GPU memory.)
  for (const name of NAMES) if (canvas[name]) canvas[name].release();

  canvas.object       = love.graphics.newCanvas(cWidth, cHeight);
  canvas.shadow       = love.graphics.newCanvas(cWidth, cHeight);
  canvas.offscreen    = love.graphics.newCanvas(cWidth, cHeight);
  canvas.intermediate = love.graphics.newCanvas(cWidth, cHeight);
  canvas.temp         = love.graphics.newCanvas(200, 200);
  canvas.xray         = love.graphics.newCanvas(cWidth, cHeight);

  // The surface map stores heights, so it wants more precision than 8 bits
  // per channel (8 bits would round heights to 4 px steps). Practically every
  // browser supports rgba16f; fall back to rgba8 just in case.
  const formats = love.graphics.getCanvasFormats(true);
  const surfaceFormat = formats.rgba16f ? 'rgba16f' : 'rgba8';
  canvas.surface = love.graphics.newCanvas(cWidth, cHeight, { format: surfaceFormat });
  canvas.surface.setFilter('nearest', 'nearest');
  canvas.focus        = love.graphics.newCanvas(cWidth, cHeight);
  canvas.focusSurface = love.graphics.newCanvas(cWidth, cHeight, { format: surfaceFormat });
  canvas.focusSurface.setFilter('nearest', 'nearest');

  canvas.showSurfaceMap = canvas.showSurfaceMap || false;
  // Linear on purpose: pixelScaleShader relies on it to blend only the
  // one-screen-pixel seams between art pixels (it's still pixel-perfect at
  // whole-number zoom). See view.js.
  canvas.intermediate.setFilter('linear', 'linear');
};

// Clears the per-frame canvases. (surface / focusSurface are cleared when
// terrain draws them.)
canvas.clear = function () {
  for (const c of [canvas.object, canvas.shadow, canvas.offscreen, canvas.intermediate,
                   canvas.temp, canvas.xray, canvas.focus]) {
    love.graphics.setCanvas(c);
    love.graphics.clear(0, 0, 0, 0);
  }
  love.graphics.setCanvas();
};
