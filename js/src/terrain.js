// terrain.js
//
// Owns the elevation data and the two GPU textures the lighting shaders use
// to understand the 3D shape of the world.
//
// COORDINATE SYSTEM
// -----------------
// The game is drawn in an oblique "3/4" view: something standing at world
// position (x, y) with height h appears on screen at
//
//     screenX = x - cameraX
//     screenY = y - h - cameraY        (higher things are drawn further up)
//
// Heights here are pixels, POSITIVE UPWARD: 64 is a cliff two tiles tall,
// -32 is a pit one tile deep. (mapArray stores the opposite sign as z, e.g.
// z = -64 for that cliff, z = 32 for that pit.)
//
// Tiles are addressed (col, row) from 0 (the Lua version counts from 1):
// tile (c, r) covers world x c*32 .. c*32+31, y r*32 .. r*32+31.
//
// A tile at tile row r with height H occupies, on screen (y0 = the tile's
// top edge at ground level):
//   * its flat TOP      from y0 - H to y0 - H + 32
//   * its south FACE    from y0 - H + 32 down to y0 + 32 - B   (a vertical wall)
// where B = terrain.faceBottom(): the wall runs down to whichever is lower,
// ground level or the tile in front (south) of it. So:
//   * a raised tile's wall drops to the ground, or further into a pit in front
//   * a ground tile in front of nothing lower has no wall
//   * a ground tile BEHIND a pit has a wall down to the pit floor: that's the
//     pit's back wall, the only wall of a pit the camera can see
// A pit's floor is drawn lower on screen, so the ground in front of it hides
// part of the floor (all of it, if the pit is a tile or more deep).
//
// THE TWO TEXTURES
// ----------------
// 1. heightMap  (world space, 1 texel per tile)
//    The height of every tile. Shaders ray-march through this to answer
//    "is anything between this point and the light?" Because it covers the
//    whole map, occluders that are off-screen or hidden behind other terrain
//    still cast shadows correctly.
//
// 2. surface map  (screen space, canvas.surface, redrawn every frame)
//    For every screen pixel: is it a cliff FACE or a flat TOP, and how high
//    is that exact point? With that, a shader can turn any screen pixel back
//    into a 3D world point:
//
//        world = (screenX + cameraX, screenY + cameraY + h, h)
//
//    Channels:  R = 1 on cliff faces, 0 on tops/ground
//               G = water depth / heightRange on water surfaces (see water.js)
//               B = height / terrain.heightRange, NEGATIVE in pits (the
//                   canvas is 16-bit float, so negatives are fine). Faces
//                   have a vertical gradient: top height at the top edge,
//                   faceBottom at the base.
//               A = 1
//
//    It is built from one Mesh containing every tile that isn't plain flat
//    ground, drawn in a single call with the camera offset, so it costs about
//    the same as drawing one sprite.

import love from '../love/index.js';
import canvas from './canvas.js';
import shader from './shader.js';
import window from './window.js';

const terrain = {};
export default terrain;

terrain.tileSize    = 32;
terrain.heightRange = 1024;  // surface map stores height / heightRange (keeps values in -1..1)

// The heightmap texture stores unsigned 16-bit numbers, so heights are
// stored with this added (and subtracted again in terrainCommon.glsl).
terrain.heightBias  = 32768;

// Shadow ray-march settings. These MUST match SUN_STEP/SUN_STEPS in
// shaders/terrainCommon.glsl so CPU and GPU agree on what's in shadow.
terrain.sunStep  = 3;
terrain.sunSteps = 160;

// Reads mapArray and builds everything. To change one tile's height at
// runtime use terrain.setTileHeight (changing tile TYPES, e.g. plowing,
// needs nothing).
terrain.build = function (map) {
  this.map = map;
  this.rows = map.length;
  this.cols = 0;
  for (let r = 0; r < this.rows; r++) {
    this.cols = Math.max(this.cols, map[r].length);
  }

  // Heights in pixels (positive up), [row][col]. Missing cells (ragged rows) = 0.
  // Floating blocks: map cell [2] is the height of a block's underside
  // (0 or missing = no block). See FLOATING BLOCKS below.
  this.version = (this.version || 0) + 1;   // bumped whenever heights change
  this.heights = [];
  this.blocks = new Map();                   // row -> Map(col -> underside)
  for (let r = 0; r < this.rows; r++) {
    const row = [];
    for (let c = 0; c < this.cols; c++) {
      const cell = map[r][c];
      row[c] = cell ? -cell[1] : 0;
      if (cell && cell[2] && cell[2] !== 0) {
        if (!this.blocks.has(r)) this.blocks.set(r, new Map());
        this.blocks.get(r).set(c, cell[2]);
      }
    }
    this.heights[r] = row;
  }
  this.updateExtents();

  this.buildHeightMap();
  this.buildSurfaceMesh();
};

// FLOATING BLOCKS
// A tile can have one floating block: a 32 px cube whose underside is at
// `bottom` px (so its top is at bottom + 32), with open space between it
// and the ground. Blocks are part of the terrain for drawing and lighting
// (their top and front faces are in the surface map, they cast shadows via
// the heightmap's B channel), and the player can stand on them, walk under
// them, and bump into them (player.js).
terrain.blockSize = 32;

// Underside height (px) of the block on tile (col, row), or undefined.
// (Compare with `!= null`, not truthiness: an underside can be 0.)
terrain.blockAt = function (col, row) {
  const r = this.blocks.get(row);
  return r ? r.get(col) : undefined;
};

// Adds a block over tile (col, row) with its underside at `bottom` px, or
// removes it (bottom = null). Bottoms are rounded to 8 px (heightmap storage).
terrain.setBlock = function (col, row, bottom) {
  const cell = this.map[row] && this.map[row][col];
  if (!cell) return;
  if (bottom != null) bottom = Math.floor(bottom / 8 + 0.5) * 8;
  cell[2] = bottom ?? 0;
  if (!this.blocks.has(row)) this.blocks.set(row, new Map());
  if (bottom != null) this.blocks.get(row).set(col, bottom);
  else this.blocks.get(row).delete(col);
  this.version = this.version + 1;
  this.updateExtents();
  this.writeHeightTexel(col, row);
  this.heightMap.replacePixels(this.heightData);
  this.buildSurfaceMesh();
};

// Height of the highest surface on tile (col, row) that something at height
// `h` could be standing on: the block's top if it's at or below h, otherwise
// the ground.
terrain.supportAt = function (col, row, h) {
  const ground = this.heightAtTile(col, row);
  const b = this.blockAt(col, row);
  if (b != null && b + this.blockSize <= h + 0.5 && b + this.blockSize > ground) {
    return b + this.blockSize;
  }
  return ground;
};

// Recomputes maxHeight and minHeight. maxHeight is the highest thing that
// can block light: the tallest tile or the top of the highest block (>= 0).
// minHeight is the deepest pit (<= 0). Shaders use these to stop shadow
// rays early and to size their work.
terrain.updateExtents = function () {
  this.maxHeight = 0;
  this.minHeight = 0;
  for (let r = 0; r < this.rows; r++) {
    for (let c = 0; c < this.cols; c++) {
      const h = this.heights[r][c];
      if (h > this.maxHeight) this.maxHeight = h;
      if (h < this.minHeight) this.minHeight = h;
    }
  }
  for (const row of this.blocks.values()) {
    for (const b of row.values()) {
      this.maxHeight = Math.max(this.maxHeight, b + this.blockSize);
    }
  }
  if (!(this.maxHeight < this.heightRange && -this.minHeight < this.heightRange)) {
    throw new Error('terrain taller/deeper than heightRange; raise terrain.heightRange');
  }
};

// [high byte, low byte] of a height, as 0..1 channel values.
function encodeHeight(h) {
  const v = h + terrain.heightBias;
  return [Math.floor(v / 256) / 255, (v % 256) / 255];
}

// Changes the height (px, positive = up, negative = pit) of one tile and
// updates everything that depends on it: the map cell's z, the heightmap
// texel, the tallest/deepest heights, and the surface mesh. Cheap enough to
// call on a key press.
terrain.setTileHeight = function (col, row, h) {
  const cell = this.map[row] && this.map[row][col];
  if (!cell) return;

  cell[1] = -h;
  this.heights[row][col] = h;
  this.version = this.version + 1;   // lets water.js notice the land changed
  this.updateExtents();   // ~10,000 comparisons: instant, and never stale

  this.writeHeightTexel(col, row);
  this.heightMap.replacePixels(this.heightData);
  this.buildSurfaceMesh();
};

// Writes tile (col, row) into the heightmap data:
//   R, G  ground height + heightBias (high byte, low byte)
//   B     floating block: 0 = none, else (underside / 8 + 128) / 255,
//         so undersides from -1016 to +1008 px in 8 px steps
// Decoded by terrainAt() in terrainCommon.glsl.
terrain.writeHeightTexel = function (col, row) {
  const [hi, lo] = encodeHeight(this.heights[row][col]);
  const b = this.blockAt(col, row);
  const blockByte = b != null ? (b / 8 + 128) / 255 : 0;
  this.heightData.setPixel(col, row, hi, lo, blockByte, 1);
};

// Height (px) at the bottom of tile (col, row)'s south wall: the lower of
// ground level and the tile in front of it. If this isn't below the tile's
// own height, the tile has no visible wall.
terrain.faceBottom = function (col, row) {
  return Math.min(0, this.heightAtTile(col, row + 1));
};

// Height (px) of tile (col, row). Anything off the map is flat ground.
terrain.heightAtTile = function (col, row) {
  const r = this.heights[row];
  return (r && r[col]) || 0;
};

// Height (px) at a world-space point on the ground plane.
terrain.heightAtWorld = function (wx, wy) {
  const ts = this.tileSize;
  return this.heightAtTile(Math.floor(wx / ts), Math.floor(wy / ts));
};

// Heights (+ heightBias) are packed into two 8-bit channels (R = high byte,
// G = low byte), so they're exact for any whole-pixel height. Decoded in
// terrainCommon.glsl.
terrain.buildHeightMap = function () {
  this.heightData = love.image.newImageData(this.cols, this.rows, 'rgba8');  // kept for single-texel updates
  for (let r = 0; r < this.rows; r++) {
    for (let c = 0; c < this.cols; c++) {
      this.writeHeightTexel(c, r);
    }
  }
  if (this.heightMap) this.heightMap.release();
  this.heightMap = love.graphics.newImage(this.heightData);
  this.heightMap.setFilter('nearest', 'nearest');
};

// Returns a function quad(x0, y0, x1, y1, face, hTop, hBottom, waterDepth)
// that appends one surface-map rectangle (two triangles) to `verts`.
// Vertex colour = the surface-map channels: R face, G water depth, B height.
terrain.quadWriter = function (verts) {
  const range = this.heightRange;
  return function (x0, y0, x1, y1, face, hTop, hBottom, waterDepth) {
    const w = (waterDepth || 0) / range;
    const tl = [x0, y0, face, w, hTop / range, 1];
    const tr = [x1, y0, face, w, hTop / range, 1];
    const bl = [x0, y1, face, w, hBottom / range, 1];
    const br = [x1, y1, face, w, hBottom / range, 1];
    verts.push(tl, tr, bl, tr, br, bl);
  };
};

// Emits tile (c, r)'s surface-map quads: its south wall (if any), then its
// flat top, then its floating block (if any, and `withBlock` isn't false).
// Plain ground (height 0) gets a top only if `groundTop` is true; otherwise
// the cleared canvas already says "ground".
terrain.emitTile = function (c, r, quad, groundTop, withBlock) {
  const ts = this.tileSize;
  const H = this.heightAtTile(c, r);
  const B = this.faceBottom(c, r);
  const x0 = c * ts, y0 = r * ts;
  if (B < H) {
    quad(x0, y0 + ts - H, x0 + ts, y0 + ts - B, 1, H, B);   // wall: H at top, B at base
  }
  if (H !== 0 || groundTop) {
    quad(x0, y0 - H, x0 + ts, y0 - H + ts, 0, H, H);        // top at height H
  }
  if (withBlock !== false) this.emitBlock(c, r, quad);
};

// Emits tile (c, r)'s floating block, if it has one: its front face (a wall
// from its top down to its underside, on the tile's south edge), then its top.
terrain.emitBlock = function (c, r, quad) {
  const b = this.blockAt(c, r);
  if (b == null) return;
  const ts = this.tileSize, T = b + this.blockSize;
  const x0 = c * ts, y0 = r * ts;
  quad(x0, y0 + ts - T, x0 + ts, y0 + ts - b, 1, T, b);   // front face
  quad(x0, y0 - T, x0 + ts, y0 - T + ts, 0, T, T);        // top
};

// Frees a mesh's GPU buffers. (LÖVE does this when meshes are garbage
// collected; WebGL needs it done by hand.)
terrain.releaseMesh = function (mesh) {
  if (mesh) mesh.release();
};

// One quad for each tile's top and one for its south face, in back-to-front
// (row-major) order so nearer terrain overwrites farther terrain, exactly
// like the tile sprites do.
//
// Plain flat ground needs no quad (the canvas is cleared to "ground"),
// EXCEPT ground just in front of a pit: a pit floor is drawn lower than its
// own row, so the ground in front has to be drawn over it.
terrain.buildSurfaceMesh = function () {
  const verts = [];
  const quad = this.quadWriter(verts);

  // How many rows a pit floor can sink into the rows in front of it.
  const pitReach = Math.ceil(-this.minHeight / this.tileSize);

  for (let r = 0; r < this.rows; r++) {
    for (let c = 0; c < this.cols; c++) {
      // Ground needs a top only if a pit behind might show through.
      let groundTop = false;
      for (let k = 1; k <= pitReach; k++) {
        if (this.heightAtTile(c, r - k) < 0) { groundTop = true; break; }
      }
      this.emitTile(c, r, quad, groundTop);
    }
  }

  this.releaseMesh(this.surfaceMesh);
  this.surfaceMesh = this.newSurfaceMesh(verts);   // null for a completely flat map
  if (this.focusMeshes) {
    for (const m of this.focusMeshes.values()) this.releaseMesh(m || null);
  }
  this.focusMeshes = new Map();                    // pit layers are stale now
  this.buildHiders(pitReach);
};

// Which tiles can hide sprites drawn earlier (further back)? Raised tiles
// always can. Ground (or a shallower pit) can only hide something standing
// on LOWER ground behind it, i.e. in a pit within `pitReach` rows to the
// north. Columns 2 either side are checked too, since sprites are wider than
// a tile. Without this, every ground tile on screen would erase its
// footprint each frame whenever any pit exists, which is slow.
terrain.buildHiders = function (pitReach) {
  this.hiders = [];
  for (let r = 0; r < this.rows; r++) {
    const row = [];
    for (let c = 0; c < this.cols; c++) {
      const H = this.heights[r][c];
      let hides = H > 0;
      for (let k = 1; k <= pitReach && !hides; k++) {
        for (let dc = -2; dc <= 2; dc++) {
          if (this.heightAtTile(c + dc, r - k) < H) { hides = true; break; }
        }
      }
      row[c] = hides;
    }
    this.hiders[r] = row;
  }
};

// Does tile (col, row) hide sprites behind it? (See buildHiders.)
terrain.hidesBehind = function (col, row) {
  const r = this.hiders[row];
  return r !== undefined && r[col] === true;
};

// Float vertex colours so heights aren't rounded to 8 bits before they
// reach the (16-bit float) surface canvas.
terrain.newSurfaceMesh = function (verts) {
  if (verts.length === 0) return null;
  return love.graphics.newMesh(
    [['VertexPosition', 'float', 2], ['VertexColor', 'float', 4]],
    verts, 'triangles', 'static');
};

// Renders the visible part of the surface map into canvas.surface.
terrain.drawSurfaceMap = function (cameraX, cameraY) {
  love.graphics.setCanvas(canvas.surface);
  love.graphics.clear(0, 0, 0, 1);            // flat ground, height 0
  if (this.surfaceMesh) {
    love.graphics.setBlendMode('replace');
    love.graphics.setColor(1, 1, 1, 1);
    love.graphics.draw(this.surfaceMesh, -cameraX, -cameraY);
    love.graphics.setBlendMode('alpha');
  }
};

// PIT FOCUS LAYER
// While the player is in a pit, only the tiles at or below his level are
// also rendered on their own (see lighting.js). This is the surface-map
// mesh for that layer: tops and walls of tiles with height <= level, and
// nothing else. Built once per level and cached until the terrain changes.
terrain.focusMesh = function (level) {
  if (!this.focusMeshes.has(level)) {
    const verts = [];
    const quad = this.quadWriter(verts);
    for (let r = 0; r < this.rows; r++) {
      for (let c = 0; c < this.cols; c++) {
        if (this.heights[r][c] <= level) {
          this.emitTile(c, r, quad, true, false);   // blocks float above: not part of the pit
        }
      }
    }
    this.focusMeshes.set(level, this.newSurfaceMesh(verts) || false);
  }
  return this.focusMeshes.get(level) || null;
};

// Renders the pit layer's terrain shape into canvas.focusSurface. Alpha is 0
// wherever the layer has nothing, so the shader can tell.
terrain.drawFocusSurface = function (level, cameraX, cameraY) {
  love.graphics.setCanvas(canvas.focusSurface);
  love.graphics.clear(0, 0, 0, 0);
  const mesh = this.focusMesh(level);
  if (mesh) {
    love.graphics.setBlendMode('replace');
    love.graphics.setColor(1, 1, 1, 1);
    love.graphics.draw(mesh, -cameraX, -cameraY);
    love.graphics.setBlendMode('alpha');
  }
};

// Is tile height h part of the pit layer for `level`?
terrain.inFocusLayer = function (h, level) {
  return h <= level;
};

// Sends the uniforms declared in terrainCommon.glsl to a shader. Uniforms the
// shader compiler optimised away are skipped (LÖVE errors on those).
terrain.sendUniforms = function (s, cameraX, cameraY) {
  shader.sendIfPresent(s, 'surfaceMap', canvas.surface);
  shader.sendIfPresent(s, 'heightMap', this.heightMap);
  shader.sendIfPresent(s, 'mapTiles', [this.cols, this.rows]);
  shader.sendIfPresent(s, 'tileSize', this.tileSize);
  shader.sendIfPresent(s, 'heightRange', this.heightRange);
  shader.sendIfPresent(s, 'maxTerrainHeight', this.maxHeight);
  shader.sendIfPresent(s, 'heightBias', this.heightBias);
  shader.sendIfPresent(s, 'camera', [cameraX, cameraY]);
  shader.sendIfPresent(s, 'screenSize', [window.width, window.height]);
};

// CPU version of terrainShadow() in terrainCommon.glsl: how much of the sun
// (0..1) terrain and floating blocks block for a world point. Used to darken
// sprites (player, trees, crops) standing in a cliff's or block's shadow,
// since the GPU pass only shades terrain pixels. Sprites are small, so a
// single ray with the far-end soft fade is enough (the shader also fans rays
// sideways).
terrain.sunShadowAmount = function (wx, wy, h, sunState) {
  if (!sunState.isUp || h >= this.maxHeight) return 0;
  const maxDist = Math.min((this.maxHeight - h) / sunState.slope, this.sunStep * this.sunSteps);
  const invSoft = 0.5 / Math.max(sunState.softness, 1e-4);
  const ts = this.tileSize;
  let lit = 1;
  for (let d = this.sunStep; d <= maxDist; d += this.sunStep) {
    const rayH = h + d * sunState.slope;
    const qx = wx + sunState.dirX * d, qy = wy + sunState.dirY * d;
    const col = Math.floor(qx / ts), row = Math.floor(qy / ts);
    const tileH = this.heightAtTile(col, row);
    let v = Math.max(0, Math.min(1, 0.5 + (rayH - tileH) / d * invSoft));
    const b = this.blockAt(col, row);
    if (b != null && rayH > b && rayH < b + this.blockSize) v = 0;   // through a block
    if (v < lit) {
      lit = v;
      if (lit <= 0) return 1;
    }
  }
  return 1 - lit;
};
