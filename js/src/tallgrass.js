// tallgrass.js
//
// Swaying tall grass (tile type 10). Not drawn at the moment: nothing calls
// this (see tiles.js), same as in the LÖVE build. Kept so the two stay in
// step.

import love from '../love/index.js';
import canvas from './canvas.js';
import player from './player.js';
import shader from './shader.js';
import sprites from './sprites.js';
import window from './window.js';

const tallGrass = {};
export default tallGrass;

tallGrass.add = function (xC, yC, z, zHeight, xTileWidthOffsetX, yTileHeightOffsetY, cameraX, cameraY) {
  love.graphics.setCanvas(canvas.object);
  love.graphics.setShader(shader.grass);

  const distance2 = Math.sqrt((xTileWidthOffsetX - 10 - window.width / 2) ** 2
    + (yTileHeightOffsetY - 40 + 27 - window.height / 2) ** 2);

  if (distance2 < 20 && (player.ax !== 0 || player.ay !== 0)) {
    if (window.width / 2 > xTileWidthOffsetX - 10) {
      shader.grass.send('poop', 1.0);
    } else {
      shader.grass.send('poop', -1.0);
    }
  } else {
    shader.grass.send('poop', 0.0);
  }

  shader.grass.send('base', yTileHeightOffsetY - 40 + 27);
  love.graphics.draw(
    sprites.grass,
    sprites.grassQuad,
    xTileWidthOffsetX - 10,
    yTileHeightOffsetY - 40,
  );

  const distance1 = Math.sqrt((xTileWidthOffsetX - window.width / 2) ** 2
    + (yTileHeightOffsetY - 25 + 27 - window.height / 2) ** 2);
  if (distance1 < 20 && (player.ax !== 0 || player.ay !== 0)) {
    if (window.width / 2 > xTileWidthOffsetX) {
      shader.grass.send('poop', 1.0);
    } else {
      shader.grass.send('poop', -1.0);
    }
  } else {
    shader.grass.send('poop', 0.0);
  }
  shader.grass.send('base', yTileHeightOffsetY - 25 + 27);
  shader.grass.send('time', love.timer.getTime());
  shader.grass.send('yTile', (yC + 1) * sprites.size);
  love.graphics.draw(
    sprites.grass,
    sprites.grassQuad,
    xTileWidthOffsetX,
    yTileHeightOffsetY - 25,
  );

  love.graphics.setShader();
};
