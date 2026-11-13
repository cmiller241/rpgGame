// water.js
//
// Water lying on the terrain: how much is on each tile, how it flows, and
// getting its surface into the surface map so the lighting pass can draw it.
//
// STATE
// Each tile can hold a water DEPTH in pixels. Its water SURFACE is then
// (ground height + depth). Only wet tiles are stored.
//
// FLOW (water.update, once per fixed tick)
// Water moves from a tile to any of its 4 neighbours whose water surface is
// lower, a fraction (flowRate) of the difference per tick. That single rule
// gives:
//   * spreading out over level ground,
//   * pouring down into pits and off ledges,
//   * filling a pit, then overflowing its rim once the surface is higher.
// The total amount of water never changes. Two tweaks:
//   * Surface tension: onto DRY level ground (or up over a dry rim) water
//     only moves if the surfaces differ by more than minSpread px, so one
//     cast makes a puddle instead of thinning out across the whole map.
//     Downhill, or into water that's already there, it always moves, so
//     pools level out completely.
//   * The simulation sleeps once nothing is moving, and wakes when water is
//     added or the land changes (terrain.version).
//   * Water slowly evaporates (evaporationRate), even while asleep.
//
// DRAWING
// Water has no sprites. Its surface is written into canvas.surface (G =
// depth, B = surface height) and ultimateShader.glsl tints those pixels.
// Shallow water is drawn as rounded puddles that merge with wet neighbours,
// using the water map texture (see WATER MAP below and the shader).
// Order matters there: a pit's front rim, or a cliff in front, must cover
// water behind it. The static terrain mesh is drawn first, so for every
// column that has water we redraw that column again from the first wet row
// onward, back to front, with the water surfaces slotted in after their own
// tile. Tiles only overlap within a column, so that reproduces exactly the
// right order.

import love from '../love/index.js';
import canvas from './canvas.js';
import terrain from './terrain.js';

const water = {};
export default water;

water.castAmount = 8;     // px of water added per W press (a quarter tile)
water.maxDepth   = 320;   // px; a single tile can't hold more than this
water.flowRate   = 0.2;   // fraction of the surface difference moved per tick (<= 0.25 is stable)
water.minSpread  = 2;     // px; surface tension across level ground
water.minDepth   = 0.05;  // px; water thinner than this simply disappears

// EVAPORATION: every wet tile loses this many px of depth per second (1 px
// a minute). One press of water spreads into a puddle 1-2 px deep, so it
// dries up in about 2 minutes; a full 2-deep pit (64 px) lasts about an
// hour. Applied once a second (EVAPORATION_INTERVAL) rather than every tick.
// 0 turns it off.
water.evaporationRate = 1 / 60;
const EVAPORATION_INTERVAL = 1;

let depth = new Map();    // row -> Map(col -> px), wet tiles only
let awake = false;        // is anything still flowing?
let seenVersion = null;   // terrain.version we last simulated against
let overlayMesh = null;
let overlayDirty = true;
let evaporationTimer = 0;

// WATER MAP: a tiny texture, one pixel per tile, holding each tile's water
// depth (R = depth / 255, capped). The lighting shader reads it to draw
// shallow water as rounded puddles that join up with their neighbours.
// Updated along with the overlay.
water.map = null;
let mapData = null;
let mapWet = [];          // tiles currently non-zero in mapData, to clear next time

const NEIGHBOURS = [[1, 0], [-1, 0], [0, 1], [0, -1]];

function onMap(c, r) {
  return r >= 0 && r < terrain.rows && c >= 0 && c < terrain.cols
    && terrain.map[r] !== undefined && terrain.map[r][c] != null;
}

function setDepth(c, r, d) {
  if (d <= water.minDepth) {
    const row = depth.get(r);
    if (row) {
      row.delete(c);
      if (row.size === 0) depth.delete(r);
    }
  } else {
    let row = depth.get(r);
    if (!row) { row = new Map(); depth.set(r, row); }
    row.set(c, d);
  }
}

// Depth (px) of water on tile (col, row).
water.depthAt = function (c, r) {
  const row = depth.get(r);
  return (row && row.get(c)) || 0;
};

// Height (px) of the water surface on tile (col, row), or null if it's dry.
water.surfaceAt = function (c, r) {
  const d = this.depthAt(c, r);
  if (d <= 0) return null;
  return terrain.heightAtTile(c, r) + d;
};

// Adds `amount` px of water to tile (col, row).
water.add = function (c, r, amount) {
  if (!onMap(c, r)) return;
  setDepth(c, r, Math.min(this.maxDepth, this.depthAt(c, r) + amount));
  this.wake();
};

// Removes all water (used by devtools between scenes).
water.clear = function () {
  depth = new Map();
  awake = false;
  overlayDirty = true;
};

// How deep the water is around the player's feet: the water surface on his
// tile minus the height of his feet (so it shrinks while he jumps). 0 if dry.
water.depthAtFeet = function (wx, wy, feetHeight) {
  const ts = terrain.tileSize;
  const c = Math.floor(wx / ts), r = Math.floor(wy / ts);
  const S = this.surfaceAt(c, r);
  if (S === null) return 0;
  return Math.max(0, S - feetHeight);
};

water.wake = function () {
  awake = true;
  overlayDirty = true;
};

// Lowers every wet tile by `amount` px (evaporation).
function evaporate(amount) {
  for (const [r, row] of depth) {
    for (const [c, d] of row) {
      setDepth(c, r, d - amount);
    }
  }
  overlayDirty = true;
}

// One simulation step; call once per fixed tick with its dt. (dt may be
// omitted, e.g. by tools settling water instantly: then nothing evaporates.)
// Transfers are worked out from the current state for every tile first,
// then applied together, so the result doesn't depend on the order tiles
// are visited in.
water.update = function (dt) {
  if (dt && this.evaporationRate > 0 && depth.size > 0) {
    evaporationTimer = evaporationTimer + dt;
    if (evaporationTimer >= EVAPORATION_INTERVAL) {
      evaporate(this.evaporationRate * evaporationTimer);
      evaporationTimer = 0;
    }
  }

  if (terrain.version !== seenVersion) {   // land was dug or raised
    seenVersion = terrain.version;
    this.wake();
  }
  if (!awake) return;

  const moves = [];
  for (const [r, row] of depth) {
    for (const [c, d] of row) {
      const H = terrain.heightAtTile(c, r);
      const S = H + d;
      const first = moves.length;
      let total = 0;
      for (const [oc, or] of NEIGHBOURS) {
        const nc = c + oc, nr = r + or;
        if (onMap(nc, nr)) {
          const Hn = terrain.heightAtTile(nc, nr);
          const dn = this.depthAt(nc, nr);
          const diff = S - (Hn + dn);
          // Flows if: downhill, or into water already there (so a
          // pool levels out completely), or onto dry ground only
          // past the surface-tension threshold.
          if (diff > 0 && (Hn < H || dn > 0 || diff > this.minSpread)) {
            const amount = diff * this.flowRate;
            moves.push([c, r, nc, nr, amount]);
            total = total + amount;
          }
        }
      }
      // Can't give away more water than the tile has.
      if (total > d) {
        const scale = d / total;
        for (let i = first; i < moves.length; i++) moves[i][4] = moves[i][4] * scale;
      }
    }
  }

  // Sum each tile's net change, then apply once (exactly conserves water).
  const delta = new Map();
  let biggest = 0;
  const addDelta = (c, r, v) => {
    let row = delta.get(r);
    if (!row) { row = new Map(); delta.set(r, row); }
    row.set(c, (row.get(c) || 0) + v);
  };
  for (const m of moves) {
    addDelta(m[0], m[1], -m[4]);
    addDelta(m[2], m[3], m[4]);
    if (m[4] > biggest) biggest = m[4];
  }
  for (const [r, row] of delta) {
    for (const [c, v] of row) {
      setDepth(c, r, Math.min(this.maxDepth, this.depthAt(c, r) + v));
    }
  }

  if (moves.length > 0) overlayDirty = true;
  if (biggest < 0.01) awake = false;   // settled: sleep until woken
};

// Builds a surface-map overlay mesh: for each wet column, that column's
// terrain from its first wet row onward, with water surfaces slotted in
// (see DRAWING above). With `level`, only tiles at or below that height are
// included: the version for the pit focus layer (lighting.js).
function buildOverlay(level) {
  const ts = terrain.tileSize;
  const verts = [];
  const quad = terrain.quadWriter(verts);
  const included = (c, r) => level === undefined || terrain.heightAtTile(c, r) <= level;

  // Per column: first and last wet row, and the lowest water surface.
  const columns = new Map();
  for (const [r, row] of depth) {
    for (const [c, d] of row) {
      if (included(c, r)) {
        const col = columns.get(c);
        const S = terrain.heightAtTile(c, r) + d;
        if (!col) {
          columns.set(c, { first: r, last: r, lowest: S });
        } else {
          col.first = Math.min(col.first, r);
          col.last = Math.max(col.last, r);
          col.lowest = Math.min(col.lowest, S);
        }
      }
    }
  }

  for (const [c, col] of columns) {
    // Rows further forward whose terrain can reach up over the water.
    const reach = Math.ceil((terrain.maxHeight - col.lowest) / ts) + 1;
    for (let r = col.first; r <= Math.min(terrain.rows - 1, col.last + reach); r++) {
      if (included(c, r)) {
        terrain.emitTile(c, r, quad, true, false);   // block (if any) goes after the water
        const d = water.depthAt(c, r);
        if (d > 0) {
          const H = terrain.heightAtTile(c, r);
          const S = H + d;
          const x0 = c * ts, y0 = r * ts;
          // Water surface.
          quad(x0, y0 - S, x0 + ts, y0 - S + ts, 0, S, S, d);
          // Its front (south) face, from the surface down to the
          // tile's floor: you look through it at the floor. Usually
          // hidden behind a pit's rim; shows through pit focus.
          quad(x0, y0 + ts - S, x0 + ts, y0 + ts - H, 1, S, H, d);
        }
        if (level === undefined) terrain.emitBlock(c, r, quad);   // a block floats above the water
      }
    }
  }

  return terrain.newSurfaceMesh(verts);
}

// The pit focus layer's overlay, cached for one level until water changes.
const focusOverlay = { level: null, mesh: null, stale: true };

// Rewrites the water map texture: clears last time's wet tiles, writes the
// current ones.
function updateMap() {
  if (!mapData || mapData.getWidth() !== terrain.cols || mapData.getHeight() !== terrain.rows) {
    mapData = love.image.newImageData(terrain.cols, terrain.rows, 'rgba8');
    if (water.map) water.map.release();
    water.map = love.graphics.newImage(mapData);
    water.map.setFilter('nearest', 'nearest');
    mapWet = [];
  }
  for (const [c, r] of mapWet) mapData.setPixel(c, r, 0, 0, 0, 1);
  mapWet = [];
  for (const [r, row] of depth) {
    for (const [c, d] of row) {
      mapData.setPixel(c, r, Math.min(255, Math.ceil(d)) / 255, 0, 0, 1);
      mapWet.push([c, r]);
    }
  }
  water.map.replacePixels(mapData);
}

// Draws an overlay mesh into a surface canvas.
function drawOverlayMesh(mesh, target, cameraX, cameraY) {
  if (!mesh) return;
  love.graphics.setCanvas(target);
  love.graphics.setBlendMode('replace');
  love.graphics.setColor(1, 1, 1, 1);
  love.graphics.draw(mesh, -cameraX, -cameraY);
  love.graphics.setBlendMode('alpha');
}

// Draws the water overlay into canvas.surface (and refreshes the water map
// texture). Call right after terrain.drawSurfaceMap.
water.drawSurfaceOverlay = function (cameraX, cameraY) {
  if (overlayDirty || !water.map) {
    terrain.releaseMesh(overlayMesh);
    overlayMesh = buildOverlay();
    updateMap();
    overlayDirty = false;
    focusOverlay.stale = true;
  }
  drawOverlayMesh(overlayMesh, canvas.surface, cameraX, cameraY);
};

// Draws water in the pit focus layer into canvas.focusSurface. Call right
// after terrain.drawFocusSurface (and after drawSurfaceOverlay this frame).
water.drawFocusOverlay = function (level, cameraX, cameraY) {
  if (focusOverlay.stale || focusOverlay.level !== level) {
    terrain.releaseMesh(focusOverlay.mesh);
    focusOverlay.mesh = buildOverlay(level);
    focusOverlay.level = level;
    focusOverlay.stale = false;
  }
  drawOverlayMesh(focusOverlay.mesh, canvas.focusSurface, cameraX, cameraY);
};

// Total water on the map (px of depth summed over tiles), for tests.
water.total = function () {
  let sum = 0;
  for (const row of depth.values()) {
    for (const d of row.values()) sum = sum + d;
  }
  return sum;
};
