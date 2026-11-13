// mountain.js
//
// Adds the ART for a tile's south-facing wall to the tile sprite batch: the
// face of a cliff, or the back wall of a pit. (Lighting/shadow data for
// walls lives in terrain.js; this file is only about which sprites to draw.)
//
// A tile's wall runs from its own height H down to terrain.faceBottom(),
// which is the lower of ground level and the tile in front of it. It's drawn
// as a column of 32 px face sprites from the bottom row up. Examples:
//   * a 2-tile cliff on flat ground: wall from 64 down to 0, two rows
//   * the same cliff with a 1-deep pit in front: from 64 down to -32, three rows
//   * a ground tile behind a 1-deep pit: from 0 down to -32 (the pit's back wall)
//
// SPRITE SHEET LAYOUT (img/sprites2.png, quads numbered left-to-right,
// top-to-bottom from 1). Face sprites come in four groups of four:
//
//     23-26  a face that is only one tile tall
//     27-30  bottom row of a taller face
//     31-34  middle rows of a taller face
//     35-38  top row of a taller face
//
// Within each group, add:
//     +1  if the tile to the RIGHT has a wall covering this row
//         (so no right-hand edge/corner should be drawn)
//     +2  if the tile to the LEFT has a wall covering this row (no left edge)
//
// Quad 45 is a dark gradient stretched over the whole face for depth.

import sprites from './sprites.js';
import terrain from './terrain.js';

const mountain = {};
export default mountain;

const FACE_SINGLE = 23, FACE_BOTTOM = 27, FACE_MIDDLE = 31, FACE_TOP = 35;
const FACE_GRADIENT = 45;

// Does tile (col, row) have a wall covering the 32 px band starting at
// height `bandBottom`?
function wallCovers(col, row, bandBottom) {
  const top = terrain.heightAtTile(col, row);
  const bottom = Math.min(top, terrain.faceBottom(col, row));
  return top > bandBottom && bottom <= bandBottom;
}

// xC, yC             tile coordinates (0-based)
// z                  tile's z from mapArray (negative = raised, positive = pit)
// screenX, screenY   where the tile would be drawn at ground level
// batch              (optional) sprite batch to add to; default sprites.tileBatch
mountain.add = function (xC, yC, z, screenX, screenY, batch) {
  batch = batch || sprites.tileBatch;
  const ts = sprites.size;
  const top = -z;
  const bottom = terrain.faceBottom(xC, yC);
  if (bottom >= top) return;                   // nothing lower in front: no wall

  const rows = (top - bottom) / ts;            // wall height in tiles

  // row 0 is the bottom of the wall, row rows-1 the top (just under the
  // tile's own surface).
  for (let row = 0; row <= rows - 1; row++) {
    let quad;
    if (rows === 1) {
      quad = FACE_SINGLE;
    } else if (row === 0) {
      quad = FACE_BOTTOM;
    } else if (row === rows - 1) {
      quad = FACE_TOP;
    } else {
      quad = FACE_MIDDLE;
    }

    const bandBottom = bottom + row * ts;      // height of this row's lower edge
    if (wallCovers(xC + 1, yC, bandBottom)) quad = quad + 1;
    if (wallCovers(xC - 1, yC, bandBottom)) quad = quad + 2;

    batch.add(sprites.spritesQuads[quad], screenX, screenY - bandBottom);
  }

  // Shading gradient over the full wall, stretched to its height.
  batch.add(sprites.spritesQuads[FACE_GRADIENT],
    screenX, screenY - bottom - (rows - 1) * ts, 0, 1, rows);
};

// Screen rectangle [x, y, w, h] a tile covers: its top plus any wall below
// it. Anything drawn on the object canvas earlier (i.e. further back) inside
// this area is hidden behind it.
mountain.footprint = function (xC, yC, z, screenX, screenY) {
  const ts = sprites.size;
  const top = -z;
  const lowest = Math.min(top, terrain.faceBottom(xC, yC));
  return [screenX, screenY - top, ts, ts + top - lowest];
};
