// grass.js
//
// Grass top tiles and the little decorative "flourishes" scattered on them.

import love from '../love/index.js';
import mapArray from '../maps/map01.js';
import sprites from './sprites.js';

const grass = {};
export default grass;

// Adds the grass top for one tile to the tile batch, lifted by its height.
//
// The base grass sprite (quads 1-8) is picked by which neighbours are at the
// same height or lower, so raised grass gets an edge where it drops off:
//     +1  tile above (north) is not higher
//     +2  tile to the right is not higher
//     +4  tile to the left is not higher
grass.add = function (xC, yC, z, screenX, screenY, batch) {
  batch = batch || sprites.tileBatch;
  let tile = 1;
  const row = mapArray[yC];
  if (yC > 0 && mapArray[yC - 1][xC] && mapArray[yC - 1][xC][1] <= z) tile = tile + 1;
  if (row[xC + 1] && row[xC + 1][1] <= z) tile = tile + 2;
  if (row[xC - 1] && row[xC - 1][1] <= z) tile = tile + 4;

  batch.add(sprites.spritesQuads[tile], screenX, screenY + z);
};

// Which flourish sprite (quads 11-22) each tile gets. Worked out once at load
// instead of picking one for every tile every frame. Each tile is seeded
// from its position with the same formula as the Lua (with its 1-based tile
// numbers), but LÖVE's random generator isn't reproducible in a browser, so
// the scattering is a different (still fixed) pattern from the LÖVE build's.
const flourishes = [];

grass.buildFlourishes = function () {
  const rng = love.math.newRandomGenerator(1);
  for (let yC = 0; yC < mapArray.length; yC++) {
    flourishes[yC] = [];
    for (let xC = 0; xC < mapArray[yC].length; xC++) {
      rng.setSeed((yC + 1) * (xC + 1) * 2000);
      flourishes[yC][xC] = Math.floor(rng.random() * 12 + 1) + 10;
    }
  }
};

grass.addFlourish = function (xC, yC, z, screenX, screenY, batch) {
  (batch || sprites.tileBatch).add(sprites.spritesQuads[flourishes[yC][xC]], screenX, screenY + z);
};
