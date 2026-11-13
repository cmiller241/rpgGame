// main.js  (port of main.lua)
//
// FRAME OVERVIEW (love.draw)
//   1. Surface map   terrain.drawSurfaceMap - per-pixel terrain shape for lighting
//   2. Collect       walk the visible tiles row by row (back to front):
//                      * ground/cliff tile sprites -> sprites.tileBatch
//                      * sprites (trees, crops, pages, player) become draw
//                        items, each queuing its shadow caster
//   3. Shadows       spriteShadow.flush - all sprite shadows -> canvas.shadow
//   4. Draw sprites  row by row: cliffs hide what's behind them, then the
//                    row's sprites are drawn, tinted if they stand in a cliff's
//                    or another sprite's shadow (needs every caster, hence
//                    collecting first)
//   5. Ground        tileBatch -> canvas.offscreen (one draw call)
//   6. Lighting      lighting.composite - shadows, cliff lighting, lamp, LUT
//   7. Present       view.present - scale to the window, then the UI
//
// Add ?shots, ?bench or ?scene=<name> to the page address for developer
// tools (see js/src/devtools.js).
//
// MODULES
// Every file in js/src/ is a module mirroring src/*.lua: it builds an
// object, exports it, imports what it needs, and adds its functions. Two
// modules that need each other (e.g. player and message) work because
// neither uses the other while it's still loading.
//
// This file is imported by js/boot.js once every image, sound, shader and
// font has been preloaded (modules load images as they're imported, as the
// Lua modules do when required). Pixel art: boot.js also sets the default
// image filter to "nearest" before that.

import love from './love/index.js';
import { tostring, format } from './love/lua.js';
import mapArray, { water as startingWater, objects as mapObjects } from './maps/map01.js';
import xorshift16 from './src/xorshift.js';
import window from './src/window.js';
import canvas from './src/canvas.js';
import view from './src/view.js';
import camera from './src/camera.js';
import shader from './src/shader.js';
import sun from './src/sun.js';
import sprites from './src/sprites.js';
import terrain from './src/terrain.js';
import water from './src/water.js';
import spriteShadow from './src/spriteShadow.js';
import lighting from './src/lighting.js';
import tiles from './src/tiles.js';
import mountain from './src/mountain.js';
import grass from './src/grass.js';
import dirt from './src/dirt.js';
import player from './src/player.js';
import object from './src/objects.js';
import ui from './src/ui.js';
import message from './src/message.js';
import devtools from './src/devtools.js';

let appWidth, appHeight;
let accumulator = 0; // For fixed time-step
let alpha = 0;       // How far into the next update tick we are (0..1), for smooth drawing
let seed;            // Pseudorandom seed for map updates
let debugFontSmall, debugFontLarge;

love.load = function (args) {
  love.window.setMode(1280, 800, { resizable: true, vsync: false });   // (no-op in a browser: the page sets the size)
  love.window.setTitle('Scattered Verses');

  [appWidth, appHeight] = love.graphics.getDimensions();
  canvas.initialize(window.width, window.height);
  terrain.build(mapArray);
  grass.buildFlourishes();

  // Starting water and the player's spawn point come from the map file
  // (its tiles are 1-based; water.add takes 0-based tiles).
  for (const [c, r, depth] of startingWater) water.add(c - 1, r - 1, depth);
  const spawn = mapObjects.find((o) => o.type === 'spawn') || { x: 100, y: 250 };
  player.teleport(spawn.x, spawn.y, -player.supportHeight(spawn.x, spawn.y, -100000));

  // Fonts are created once; making them every frame leaks memory fast.
  debugFontSmall = love.graphics.newFont(12);
  debugFontLarge = love.graphics.newFont(32);

  seed = 1; // Starting seed for xorshift16 map updates

  view.resize(appWidth, appHeight);  // size the game view for the starting zoom
  camera.snap();

  devtools.start(args);              // no-op unless ?shots / ?bench / ?scene= was given
};

love.resize = function (w, h) {
  appWidth = w;
  appHeight = h;
  view.resize(appWidth, appHeight);
  ui.resize(appWidth, appHeight);
};

love.keypressed = function (key) {
  if (message.isActive) {
    if (message.keypressed(key)) {
      return; // Key handled by message system
    }
  }
  if (key === 'c') {
    canvas.showSurfaceMap = !canvas.showSurfaceMap;
  } else if (key === 'z') {
    view.step(1, appWidth, appHeight);    // zoom in one level
  } else if (key === 'x') {
    view.step(-1, appWidth, appHeight);   // zoom out one level
  } else if (key === 'a' || key === 's' || key === 'r') {
    ui.keypressed(key);
  } else {
    player.keypressed(key);
  }
};

love.keyreleased = function (key) {
  if (!message.isActive) {
    player.keyreleased(key);
  }
};

// Watered crops grow one stage at random moments: each tick, 20 random
// cells are checked (xorshift16 visits all 65535 values before repeating,
// so every cell gets its turn).
function growCrops() {
  for (let i = 1; i <= 20; i++) {
    seed = xorshift16(seed);
    if (seed <= 10000) {
      const y = Math.floor((seed - 1) / 100);   // Row 0-99
      const x = (seed - 1) % 100;               // Column 0-99
      const cell = mapArray[y] && mapArray[y][x];
      // Watered (odd) and not fully grown: becomes the next dry stage.
      if (cell && tiles.isWetCrop(cell[0]) && cell[0] < 87) {
        cell[0] = cell[0] + 1;
      }
    }
  }
}

// Longest frame the fixed-step loop will catch up on. A browser stops
// drawing hidden tabs, so coming back can mean one huge dt; without a cap
// the game would grind through minutes of ticks at once. (LÖVE keeps
// running in the background, so it doesn't need this.)
const MAX_FRAME_TIME = 0.25;

love.update = function (dt) {
  dt = Math.min(dt, MAX_FRAME_TIME);
  const fixedDt = 1 / 60;
  accumulator = accumulator + dt;

  while (accumulator >= fixedDt) {
    player.rememberPosition();      // for smooth drawing between ticks
    if (!message.isActive) {
      player.update(fixedDt);
    }
    sun.update(fixedDt);      // day/night cycle (+ M/N to scrub time)
    ui.update(fixedDt); // Update UI animations
    message.update(fixedDt); // Update message typing
    growCrops();
    water.update(fixedDt);   // water flows (sleeps once settled) and slowly evaporates

    // Update object animations
    for (const obj of object.objects) {
      obj.animationTime = obj.animationTime + fixedDt;
    }
    accumulator = accumulator - fixedDt;
  }
  alpha = accumulator / fixedDt;

  // (The LÖVE build quits on Escape; a browser tab can't close itself.)

  player.updateDrawPosition(alpha);
  view.update(dt, appWidth, appHeight);   // zoom glide (Z / X); resizes the game view when needed
  camera.update(dt);                      // follow the player, clamped to the map
};

// Sort sprites within a row by where they touch the ground (lower on screen
// = closer to the camera = drawn later), then left to right.
function bySortKey(a, b) {
  if (a.sortY !== b.sortY) {
    return a.sortY - b.sortY;
  }
  return a.sortX - b.sortX;
}

// Extra tiles processed beyond the screen edges, so things just off screen
// still cast shadows into view: a tree (~250 px tall) at the lowest sun
// (45 degrees) throws a shadow ~250 px, about 8 tiles.
const MARGIN_TILES = 9;

const rows = [];  // per visible map row: { items, occluders, blocks }, reused each frame

// Erases rectangles [x, y, w, h] from canvas.object (to transparent).
function eraseFromObjects(rects) {
  love.graphics.setCanvas(canvas.object);
  love.graphics.setBlendMode('replace');
  love.graphics.setColor(0, 0, 0, 0);
  for (const o of rects) {
    love.graphics.rectangle('fill', o[0], o[1], o[2], o[3]);
  }
  love.graphics.setBlendMode('alpha');
  love.graphics.setColor(1, 1, 1, 1);
}

love.draw = function () {
  const ts = sprites.size;
  canvas.clear();
  sprites.tileBatch.clear();
  spriteShadow.clear();

  const [cameraX, cameraY] = camera.get();
  const tilesHorizontal = Math.ceil(window.width / ts);
  const tilesVertical = Math.ceil(window.height / ts);
  const firstTileX = Math.floor(cameraX / ts);
  const firstTileY = Math.floor(cameraY / ts);
  const offsetX = cameraX - firstTileX * ts;   // (Lua's cameraX % ts)
  const offsetY = cameraY - firstTileY * ts;

  // 1. Sun/lamp state for this frame, and the terrain's shape on screen.
  lighting.begin();
  terrain.drawSurfaceMap(cameraX, cameraY);
  water.drawSurfaceOverlay(cameraX, cameraY);

  // Which row each Bible page and the player belong to.
  const pagesByRow = new Map();
  for (const obj of object.objects) {
    const r = object.rowOf(obj);
    if (!pagesByRow.has(r)) pagesByRow.set(r, []);
    pagesByRow.get(r).push(obj);
  }
  const playerRow = Math.floor(player.drawY / ts);

  // 2. Collect, one tile row at a time from the back (top) to the front.
  // Rows below the screen are included because tall cliffs there reach up
  // into view and sprites there cast shadows up into view. Rows above the
  // screen are included when there are pits, since a pit floor is drawn
  // lower than its row and can sink into view.
  //
  // (y counts screen rows: row y is drawn starting at y * ts - offsetY.
  // The range matches the Lua's 1-based one, shifted down by 1.)
  const extraRows = Math.max(Math.ceil(terrain.maxHeight / ts) + 1, MARGIN_TILES);
  const rowsAbove = Math.ceil(-terrain.minHeight / ts);
  // Pit focus (lighting.js): while active, tiles at or below the player's
  // level are ALSO drawn into a separate layer.
  const focus = lighting.focus;
  const focusOn = focus.amount > 0;
  sprites.focusBatch.clear();
  let rowCount = 0;
  for (let y = -rowsAbove - 1; y < tilesVertical + extraRows; y++) {
    const yC = firstTileY + y;
    if (yC >= 0 && yC < mapArray.length) {
      let row = rows[rowCount];
      if (!row) { row = { items: [], occluders: [], blocks: [] }; rows[rowCount] = row; }
      rowCount = rowCount + 1;
      const items = row.items, occluders = row.occluders, blocks = row.blocks;
      items.length = 0;
      occluders.length = 0;
      blocks.length = 0;

      for (let x = -MARGIN_TILES - 1; x < tilesHorizontal + MARGIN_TILES; x++) {
        const xC = firstTileX + x;
        const cell = mapArray[yC][xC];
        if (cell) {
          // Screen position of this tile at ground level.
          const screenX = x * ts - offsetX;
          const screenY = y * ts - offsetY;
          const tile = cell[0], z = cell[1];
          const def = tiles.get(tile);

          // Wall below this tile (cliff face or a pit's back wall), if any.
          mountain.add(xC, yC, z, screenX, screenY);
          // Raised tiles, and ground just in front of a pit, hide
          // sprites behind them (terrain.buildHiders).
          if (terrain.hidesBehind(xC, yC)) {
            occluders.push(mountain.footprint(xC, yC, z, screenX, screenY));
          }

          grass.add(xC, yC, z, screenX, screenY);  // every tile sits on grass
          if (def.ground === 'dirt') dirt.add(xC, yC, z, screenX, screenY);
          if (def.flourish) grass.addFlourish(xC, yC, z, screenX, screenY);

          if (focusOn && terrain.inFocusLayer(-z, focus.level)) {
            const fb = sprites.focusBatch;
            mountain.add(xC, yC, z, screenX, screenY, fb);
            grass.add(xC, yC, z, screenX, screenY, fb);
            if (def.ground === 'dirt') dirt.add(xC, yC, z, screenX, screenY, fb);
            if (def.flourish) grass.addFlourish(xC, yC, z, screenX, screenY, fb);
          }
          if (def.addSprites) def.addSprites(items, xC, yC, z, screenX, screenY, tile);

          // Floating block: front face, then top, over this tile.
          const bottom = terrain.blockAt(xC, yC);
          if (bottom != null) {
            sprites.tileBatch.add(sprites.blockFrontQuad, screenX, screenY - bottom);
            sprites.tileBatch.add(sprites.blockTopQuad, screenX, screenY - bottom - ts);
            blocks.push([screenX, screenY - bottom - ts, ts, 2 * ts]);
          }
        }
      }

      for (const obj of pagesByRow.get(yC) || []) {
        object.addSprites(items, obj, cameraX, cameraY);
      }
      if (yC === playerRow) {
        player.addSprites(items, cameraX, cameraY);
      }
    }
  }

  // 3. Every queued sprite shadow (one draw call per sprite sheet).
  spriteShadow.flush(lighting.sun, lighting.lamp, cameraX, cameraY);

  // 4. Sprites, back to front.
  for (let r = 0; r < rowCount; r++) {
    const row = rows[r];

    // Cliffs in this row hide anything already drawn behind them.
    // (This row's own sprites are drawn after, so they stay in front.)
    if (row.occluders.length > 0) eraseFromObjects(row.occluders);

    row.items.sort(bySortKey);
    const drawItems = (last) => {
      for (const item of row.items) {
        if ((item.drawLast || false) === last) {
          const tint = lighting.objectTint(item.tintX, item.tintY, item.tintZ, item.caster);
          item.owner.drawItem(item, tint);
        }
      }
    };
    drawItems(false);

    // Floating blocks in this row are in front of everything else in the
    // row (they span the whole tile, back to front edge), so they hide
    // what's been drawn behind them. Anyone standing ON a block in this row
    // (item.drawLast) is drawn afterwards, on top.
    if (row.blocks.length > 0) eraseFromObjects(row.blocks);
    drawItems(true);
  }

  // 5. Ground tiles (and the pit layer, if the player is in a pit).
  love.graphics.setCanvas(canvas.offscreen);
  love.graphics.draw(sprites.tileBatch);
  player.drawOutline(cameraX, cameraY, mapArray);
  if (focusOn) {
    love.graphics.setCanvas(canvas.focus);
    love.graphics.draw(sprites.focusBatch);
    terrain.drawFocusSurface(focus.level, cameraX, cameraY);
    water.drawFocusOverlay(focus.level, cameraX, cameraY);
  }

  // 6. Lighting, shadows and colour grading.
  lighting.composite(cameraX, cameraY);

  // Debug (C key): overlay the surface map.
  if (canvas.showSurfaceMap) {
    love.graphics.setShader(shader.surfaceDebug);
    shader.surfaceDebug.send('heightRange', terrain.heightRange);
    shader.surfaceDebug.send('maxTerrainHeight', terrain.maxHeight);
    love.graphics.draw(canvas.surface);
    love.graphics.setShader();
  }

  // 7. Scale up to the window (crisp, see view.js).
  view.present(appWidth, appHeight);

  // Draw inventory UI if not showing message box
  if (!message.isActive) {
    ui.drawInventory(appWidth, appHeight);
  }

  // Draw message box
  message.draw(appWidth, appHeight);

  if (devtools.hideOverlay) return;

  // Debug readout
  love.graphics.setColor(1, 1, 1, 1);
  love.graphics.setFont(debugFontSmall);
  const stats = love.graphics.getStats();
  love.graphics.print('Player Z: ' + tostring(player.z), 10, 10);
  love.graphics.print('IsOnGround: ' + tostring(player.isOnGround), 10, 30);
  love.graphics.print('Player Jump: ' + tostring(player.jump), 10, 50);
  love.graphics.print(format('Sun Angle: %.1f', sun.angle), 10, 70);
  love.graphics.print('Draw Calls: ' + stats.drawcalls, 10, 90);
  love.graphics.print('Canvas Switches: ' + stats.canvasswitches, 10, 110);
  love.graphics.print(format('Zoom: %.2fx  (view %dx%d)', view.displayZoom, window.width, window.height), 10, 130);
  love.graphics.setFont(debugFontLarge);
  love.graphics.print('FPS: ' + love.timer.getFPS(), 10, 150);
};

// For poking at the game from the browser console while debugging.
Object.assign(globalThis.__scatteredVerses ??= {}, {
  love, mapArray, player, terrain, water, message, ui, sun, view, camera, object,
});
