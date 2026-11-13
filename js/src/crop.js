// crop.js
//
// Crops growing on dirt (tile types 72-87) plus the wet-soil overlay (70).
//
// Tile numbering: each growth stage has a dry (even) and watered (odd) tile,
// 72/73 = seeds, 74/75 = sprout, ... 86/87 = fully grown.

import love from '../love/index.js';
import canvas from './canvas.js';
import spriteShadow from './spriteShadow.js';
import sprites from './sprites.js';
import tiles from './tiles.js';

const crop = {};
export default crop;

// Where the stem meets the soil inside each 112x112 crop quad, and the
// quad point that's placed at (tile + DRAW_OFFSET).
const ANCHOR_X = 55, ANCHOR_Y = 82;
const ORIGIN_X = 55, ORIGIN_Y = 85;
const DRAW_OFFSET_X = 15, DRAW_OFFSET_Y = 27;

// Called while building the scene (see main.js). Adds the wet-soil overlay
// (for watered tiles) and the plant itself, and queues the plant's shadow.
crop.addSprites = function (list, xC, yC, z, screenX, screenY, tile) {
  if (tiles.isWetCrop(tile)) {
    this.addLayer(list, xC, yC, z, screenX, screenY, 70, screenY + 23);
  }
  this.addLayer(list, xC, yC, z, screenX, screenY, tile, screenY + 24);
};

crop.addLayer = function (list, xC, yC, z, screenX, screenY, tile, sortY) {
  const ts = sprites.size;
  let quad;
  if (tile === 70) {
    quad = sprites.cropQuads[1];                         // wet soil
  } else {
    quad = sprites.cropQuads[Math.floor((tile - 72) / 2) + 2];
  }

  // Water and seeds lie flat: no sway, no shadow.
  const isFlat = (tile === 70 || tile === 72 || tile === 73);

  const baseX = xC * ts + DRAW_OFFSET_X + (ANCHOR_X - ORIGIN_X);
  const baseY = yC * ts + DRAW_OFFSET_Y + (ANCHOR_Y - ORIGIN_Y);
  const baseZ = -z;

  let caster;
  if (!isFlat) {
    const [qx, qy, qw, qh] = quad.getViewport();
    caster = {
      image: sprites.crop, data: sprites.cropData,
      quadX: qx, quadY: qy, quadW: qw, quadH: qh,
      anchorX: ANCHOR_X, anchorY: ANCHOR_Y,
      worldX: baseX, worldY: baseY, worldZ: baseZ,
    };
    spriteShadow.add(caster);
  }

  list.push({
    owner: this, caster, quad,
    // (yC + 1: the Lua's 1-based row, for the same sway phase.)
    sway: isFlat ? 0 : Math.sin(love.timer.getTime() + yC + 1) * 0.08,
    sortY, sortX: screenX,
    drawX: screenX + DRAW_OFFSET_X, drawY: screenY + z + DRAW_OFFSET_Y,
    tintX: baseX, tintY: baseY, tintZ: baseZ + 16,
  });
};

crop.drawItem = function (item, tint) {
  love.graphics.setCanvas(canvas.object);
  love.graphics.setColor(tint, tint, tint, 1);
  love.graphics.draw(sprites.crop, item.quad, item.drawX, item.drawY, item.sway, 1, 1, ORIGIN_X, ORIGIN_Y);
  love.graphics.setColor(1, 1, 1, 1);
};
