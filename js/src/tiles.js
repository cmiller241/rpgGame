// tiles.js
//
// One place that says what every tile type in mapArray IS: what's drawn on
// the ground, what sprite stands on it, and what blocks movement. main.js's
// scene loop and player collision both read from here, so adding a tile type
// means adding one entry below.
//
// A map cell is [type, z, floatingBlockUnderside]. Types:
//
//     1        grass (with a random decorative flourish)
//     10       tall grass (drawing currently disabled)
//     56       plowed dirt
//     70       wet-soil overlay (only used as a crop layer, never in the map)
//     72-87    crops on dirt: 72/73 seeds ... 86/87 fully grown
//              (even = dry, odd = watered)
//     512      oak tree
//     520      pine tree
//
// Entry fields:
//     name      for debugging
//     ground    "grass" or "dirt": the base tile drawn under everything
//     flourish  true to scatter a decorative grass sprite on it
//     solid     collision rectangle {x, y, w, h} in px inside the tile
//               (0,0 = top-left), or undefined if walkable
//     addSprites(list, xC, yC, z, screenX, screenY, tileType)
//               appends this tile's sprites (trees, crops...) to the row's
//               draw list; see main.js

import crop from './crop.js';
import mapArray from '../maps/map01.js';
import sprites from './sprites.js';
import tree from './tree.js';

const tiles = {};
export default tiles;

// Trees block only around the trunk, so you can walk behind the canopy.
const TRUNK = { x: 6, y: 18, w: 20, h: 12 };

const types = {};

types[1]   = { name: 'grass', ground: 'grass', flourish: true };
types[10]  = { name: 'tall grass', ground: 'grass' };
types[56]  = { name: 'plowed dirt', ground: 'dirt' };
types[512] = { name: 'oak tree', ground: 'grass', solid: TRUNK,
               addSprites: (list, ...args) => tree.addSprites(list, 'oak', ...args) };
types[520] = { name: 'pine tree', ground: 'grass', solid: TRUNK,
               addSprites: (list, ...args) => tree.addSprites(list, 'pine', ...args) };

const cropType = { name: 'crop', ground: 'dirt',
                   addSprites: (list, ...args) => crop.addSprites(list, ...args) };
for (let t = 72; t <= 87; t++) types[t] = cropType;

// Anything not listed (e.g. a typo in the map) is drawn as plain grass.
const unknown = { name: 'unknown', ground: 'grass' };

tiles.get = function (tileType) {
  return types[tileType] || unknown;
};

// Crop helpers (used by player tools and crop growth).
tiles.isCrop    = (t) => t >= 72 && t <= 87;
tiles.isDryCrop = (t) => t >= 72 && t <= 86 && t % 2 === 0;
tiles.isWetCrop = (t) => t >= 73 && t <= 87 && t % 2 === 1;
tiles.isDirt    = (t) => t === 56 || tiles.isCrop(t);

// Does the world-space rectangle (x0..x1, y0..y1, inclusive px) overlap a
// solid part of tile (col, row)? Off-map tiles are fully solid.
tiles.blocks = function (col, row, x0, y0, x1, y1) {
  const cell = mapArray[row] && mapArray[row][col];
  if (!cell) return true;
  const solid = tiles.get(cell[0]).solid;
  if (!solid) return false;
  const ts = sprites.size;
  const sx0 = col * ts + solid.x;
  const sy0 = row * ts + solid.y;
  const sx1 = sx0 + solid.w - 1;
  const sy1 = sy0 + solid.h - 1;
  return x0 <= sx1 && x1 >= sx0 && y0 <= sy1 && y1 >= sy0;
};
