// dirt.js
//
// Plowed dirt tiles (tile type 56 and the crop tiles 72-87 sitting on dirt).

import mapArray from '../maps/map01.js';
import sprites from './sprites.js';
import tiles from './tiles.js';

const dirt = {};
export default dirt;

function isDirt(x, y) {
  const cell = mapArray[y] && mapArray[y][x];
  return cell !== undefined && tiles.isDirt(cell[0]);
}

// Adds a dirt tile to the tile batch. The sprite (quads 56-71) is picked by
// which neighbours are also dirt, so patches join up seamlessly:
//     +1 up   +2 left   +4 right   +8 down
dirt.add = function (xC, yC, z, screenX, screenY, batch) {
  batch = batch || sprites.tileBatch;
  let tile = 56;
  // (Previously "type >= 56", which also counted trees as dirt.)
  if (isDirt(xC, yC - 1)) tile = tile + 1;
  if (isDirt(xC - 1, yC)) tile = tile + 2;
  if (isDirt(xC + 1, yC)) tile = tile + 4;
  if (isDirt(xC, yC + 1)) tile = tile + 8;

  batch.add(sprites.spritesQuads[tile], screenX, screenY + z);
};
