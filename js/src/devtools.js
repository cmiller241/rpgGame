// devtools.js
//
// Developer tools. In the LÖVE build they're started from the command line
// (love . --shots); in the browser, add them to the page's address as
// query parameters instead:
//
//   index.html?shots   Renders each scene in SCENES (fixed sun angle, player
//                      position and zoom), then shows a contact sheet of them
//                      all and downloads it (shots_sheet.png). Handy for
//                      checking lighting/shadow changes without walking to
//                      the right spot at the right time of day.
//
//   index.html?bench   Renders each scene for a few seconds and prints the
//                      average frame time (to the console and the screen;
//                      bench.txt is downloaded).
//
//   index.html?scene=<name>   (Browser only.) Starts the game in one of the
//                      scenes below, e.g. ?scene=water_pools, and then plays
//                      on as normal.
//
// Game updates are frozen while shots/bench run, so results are repeatable.

import love from '../love/index.js';
import { format } from '../love/lua.js';
import camera from './camera.js';
import canvas from './canvas.js';
import lighting from './lighting.js';
import player from './player.js';
import sun from './sun.js';
import terrain from './terrain.js';
import tree from './tree.js';
import water from './water.js';
import view from './view.js';

const devtools = {};
export default devtools;

devtools.hideOverlay = false;   // hides the debug text so screenshots are clean

// Edit freely. x/y are world pixels of the player's feet; z is his height
// (negative = up, e.g. -32 for one tile; positive = down in a pit); angle is
// sun.angle (0 = sunrise, 90 = noon, 180 = sunset, 250 = night); zoom is a
// whole-number zoom level. Optional `flood` pours water before the shot the
// way the player would, one W press at a time, then lets it settle:
// [ [col, row, presses], ... ]. Optional `puddles` sets water depths directly
// after that, without letting them flow: [ [col, row, px], ... ]. Optional
// `blocks` places floating blocks: [ [col, row, underside px], ... ]. Optional
// `dig` reshapes tiles for that scene only: [ [col, row, height], ... ] with
// height in px (negative = pit).
//
// NOTE: col/row in these lists are the Lua file's 1-based tile numbers, so
// scenes can be copied between src/devtools.lua and here unchanged; they're
// converted (minus 1) when a scene is applied.

// Two pits in the open field east of the cliffs: one tile deep (cols 40-42)
// and two deep (cols 45-46), each two rows long.
const PITS = [];
for (let c = 40; c <= 42; c++) for (let r = 12; r <= 13; r++) PITS.push([c, r, -32]);
for (let c = 45; c <= 46; c++) for (let r = 12; r <= 13; r++) PITS.push([c, r, -64]);

const WATER = [
  [41, 12, 12],          // 1-deep pit (6 tiles): half full
  [45, 12, 36],          // 2-deep pit (4 tiles, holds 32 presses): overflows a little
  [44, 16, 3],           // a puddle on flat ground
];

const PUDDLES = [];
const puddle = (c, r) => PUDDLES.push([c, r, 1.9]);   // 1.9 px: too thin to spread
puddle(40, 20);                                         // lone tile: a circle
puddle(43, 20); puddle(44, 20);                         // two neighbours: an oval
puddle(47, 20); puddle(48, 20); puddle(48, 21);         // an L
for (let c = 51; c <= 53; c++) for (let r = 20; r <= 22; r++) puddle(c, r);   // 3x3 patch
puddle(57, 20); puddle(58, 21);                         // touching only at a corner

// Water in both pits, for wading.
const WADE = [[41, 12, 12], [45, 12, 24]];

// Floating blocks in the open field: a row of three you can jump onto, a
// lone one, and one high enough (64 px up) to walk under.
const BLOCKS = [[40, 16, 24], [41, 16, 24], [42, 16, 24], [45, 15, 24], [47, 17, 64]];

const SCENES = [
  { name: 'cliffs_morning',   angle: 40,  x: 560, y: 650, zoom: 2 },
  { name: 'cliffs_noon',      angle: 90,  x: 560, y: 650, zoom: 2 },
  { name: 'cliffs_afternoon', angle: 140, x: 560, y: 650, zoom: 2 },
  { name: 'cliffs_dusk',      angle: 172, x: 560, y: 650, zoom: 2 },
  { name: 'trees_morning',    angle: 40,  x: 900, y: 260, zoom: 2 },
  { name: 'trees_afternoon',  angle: 140, x: 900, y: 260, zoom: 2 },
  // Same spot beside a lone tree: in its canopy's shadow in the afternoon,
  // in sunlight in the morning (the player should be darker in the first).
  { name: 'in_tree_shade',    angle: 140, x: 1818, y: 660, zoom: 3 },
  { name: 'out_of_tree_shade', angle: 40, x: 1818, y: 660, zoom: 3 },
  { name: 'pages_and_pines',  angle: 120, x: 900, y: 520, zoom: 2 },
  { name: 'plateau_night',    angle: 250, x: 420, y: 570, z: -32, zoom: 3 },
  { name: 'zoomed_in_4x',     angle: 120, x: 560, y: 650, zoom: 4 },
  { name: 'surface_map',      angle: 60,  x: 560, y: 650, zoom: 2, surfaceMap: true },
  { name: 'pits_afternoon',   angle: 140, x: 1376, y: 360, zoom: 3, dig: PITS },
  { name: 'pits_morning',     angle: 40,  x: 1376, y: 360, zoom: 3, dig: PITS },
  { name: 'standing_in_pit',  angle: 110, x: 1280, y: 408, z: 32, zoom: 4, dig: PITS },
  // In the 2-deep pit: its floor is completely hidden by the rim normally,
  // so pit focus should reveal it.
  { name: 'in_deep_pit',      angle: 110, x: 1440, y: 408, z: 64, zoom: 4, dig: PITS },
  { name: 'pits_surface_map', angle: 110, x: 1376, y: 360, zoom: 3, dig: PITS, surfaceMap: true },
  // Player hidden behind things: the tree in front should fade, and the
  // cliff in front should show his ghost.
  { name: 'behind_tree',      angle: 110, x: 128,  y: 110, zoom: 3 },
  { name: 'behind_cliff',     angle: 110, x: 740,  y: 250, zoom: 3 },
  // Water: the 1-deep pit part filled, a 2-deep pit topped up until it
  // overflows onto the ground, and a puddle on flat ground.
  { name: 'water_pools',      angle: 120, x: 1376, y: 330, zoom: 3, dig: PITS, flood: WATER },
  { name: 'water_morning',    angle: 30,  x: 1376, y: 330, zoom: 3, dig: PITS, flood: WATER },
  { name: 'water_surface_map', angle: 120, x: 1376, y: 330, zoom: 3, dig: PITS, flood: WATER, surfaceMap: true },
  { name: 'puddle_shapes',    angle: 120, x: 1580, y: 610, zoom: 2, puddles: PUDDLES },
  // Standing in water: legs tinted below the waterline (16 px, then 48 px deep).
  { name: 'wading',           angle: 110, x: 1280, y: 408, z: 32, zoom: 4, dig: PITS, flood: WADE },
  { name: 'blocks_afternoon', angle: 130, x: 1376, y: 440, zoom: 3, blocks: BLOCKS },
  { name: 'blocks_morning',   angle: 35,  x: 1376, y: 440, zoom: 3, blocks: BLOCKS },
  { name: 'on_a_block',       angle: 110, x: 1284, y: 500, z: -56, zoom: 4, blocks: BLOCKS },
  { name: 'under_a_block',    angle: 110, x: 1472, y: 540, zoom: 4, blocks: BLOCKS },
  { name: 'wading_deep',      angle: 110, x: 1440, y: 408, z: 64, zoom: 4, dig: PITS, flood: WADE },
];

const BENCH_SECONDS = 3;

// Tiles reshaped by the current scene's `dig`, with their original heights
// (0-based col/row).
const undoDig = [];
const undoBlocks = [];

// Puts the game into a scene's state.
function applyScene(s) {
  while (undoDig.length) {
    const [c, r, h] = undoDig.pop();
    terrain.setTileHeight(c, r, h);
  }
  water.clear();
  while (undoBlocks.length) {
    const [c, r, b] = undoBlocks.pop();
    terrain.setBlock(c, r, b ?? null);
  }
  for (const [c1, r1, b] of s.blocks || []) {
    const c = c1 - 1, r = r1 - 1;
    undoBlocks.push([c, r, terrain.blockAt(c, r)]);
    terrain.setBlock(c, r, b);
  }
  for (const [c1, r1, h] of s.dig || []) {
    const c = c1 - 1, r = r1 - 1;
    undoDig.push([c, r, terrain.heightAtTile(c, r)]);
    terrain.setTileHeight(c, r, h);
  }

  for (const [c1, r1, presses] of s.flood || []) {
    for (let press = 1; press <= presses; press++) {
      water.add(c1 - 1, r1 - 1, water.castAmount);
      for (let i = 0; i < 20; i++) water.update();   // a third of a second between presses
    }
  }
  for (let i = 0; i < 3000; i++) water.update();     // let it settle
  for (const [c1, r1, px] of s.puddles || []) water.add(c1 - 1, r1 - 1, px);

  sun.angle = s.angle;
  player.teleport(s.x, s.y, s.z || 0);
  view.zoom = s.zoom;
  view.displayZoom = s.zoom;
  view.apply(...love.graphics.getDimensions());
  camera.snap();
  canvas.showSurfaceMap = s.surfaceMap || false;
}

// Builds one image with every screenshot as a labelled thumbnail.
function makeContactSheet(shots) {
  const cols = 3, thumbW = 400;
  const [w, h] = shots[0].data.getDimensions();
  const thumbH = Math.floor(h * thumbW / w);
  const rowsN = Math.ceil(shots.length / cols);
  const sheet = love.graphics.newCanvas(cols * thumbW, rowsN * (thumbH + 18));
  love.graphics.setCanvas(sheet);
  love.graphics.clear(0.1, 0.1, 0.1, 1);
  shots.forEach((shot, i) => {
    const c = i % cols, r = Math.floor(i / cols);
    const img = love.graphics.newImage(shot.data);
    love.graphics.setColor(1, 1, 1, 1);
    love.graphics.draw(img, c * thumbW, r * (thumbH + 18) + 18, 0, thumbW / w, thumbH / h);
    love.graphics.print(shot.name, c * thumbW + 4, r * (thumbH + 18) + 2);
    img.release();
  });
  love.graphics.setCanvas();
  return sheet;
}

// When a tool has finished: shows `sheet` (a Canvas) or `lines` of text
// on screen from now on, in place of the game. (LÖVE quits instead.)
function showResult(sheet, lines) {
  love.update = () => {};
  love.draw = () => {
    love.graphics.clear(0.1, 0.1, 0.1, 1);
    love.graphics.setColor(1, 1, 1, 1);
    if (sheet) {
      const [sw, sh] = love.graphics.getDimensions();
      const k = Math.min(1, sw / sheet.getWidth(), sh / sheet.getHeight());
      love.graphics.draw(sheet, 0, 0, 0, k, k);
    }
    (lines || []).forEach((line, i) => love.graphics.print(line, 10, 10 + i * 16));
  };
}

function startShots(gameDraw) {
  devtools.hideOverlay = true;
  // Only a few frames per shot: make fades instant.
  tree.FADE_SPEED = Infinity;
  lighting.focusFadeTime = 0;
  let index = 0, frame = 0;
  const shots = [];

  love.update = () => {};   // freeze the game
  love.draw = () => {
    const s = SCENES[index];
    if (frame === 0) applyScene(s);
    gameDraw();
    frame = frame + 1;
    if (frame === 3) {   // give canvases a frame to settle after resizing
      love.graphics.captureScreenshot((data) => {
        // (The LÖVE build also saves each shot as its own PNG; a browser
        // would download them one by one, so only the sheet is saved.)
        shots.push({ name: s.name, data });
        if (shots.length === SCENES.length) {
          const sheet = makeContactSheet(shots);
          sheet.newImageData().encode('png', 'shots_sheet.png');
          console.log('Rendered ' + shots.length + ' scenes; downloaded shots_sheet.png');
          showResult(sheet);
        }
      });
    } else if (frame > 3 && index < SCENES.length - 1) {
      index = index + 1;
      frame = 0;
    }
  };
}

function startBench(gameDraw) {
  let index = 0, elapsed = 0, frames = 0;
  const results = [];
  applyScene(SCENES[0]);

  love.update = (dt) => {
    elapsed = elapsed + dt;
    if (elapsed > 0.5) frames = frames + 1;       // skip warm-up
    if (elapsed > BENCH_SECONDS + 0.5) {
      const line = format('%-18s %6.2f ms/frame', SCENES[index].name, 1000 * BENCH_SECONDS / frames);
      console.log(line);
      results.push(line);
      index = index + 1;
      elapsed = 0;
      frames = 0;
      if (index >= SCENES.length) {
        love.filesystem.write('bench.txt', results.join('\n') + '\n');
        console.log('Saved bench.txt to ' + love.filesystem.getSaveDirectory());
        showResult(null, results);
        return;
      }
      applyScene(SCENES[index]);
    }
  };
  love.draw = gameDraw;
}

// Called from love.load with the "command-line arguments" (built from the
// page's query string by js/boot.js: ?shots -> "--shots").
devtools.start = function (args) {
  for (const a of args || []) {
    if (a === '--shots') return startShots(love.draw);
    if (a === '--bench') return startBench(love.draw);
    if (a.startsWith('--scene=')) {
      const name = a.slice('--scene='.length);
      const scene = SCENES.find((s) => s.name === name);
      if (scene) applyScene(scene);
      else console.warn('devtools: no scene named "' + name + '". Scenes: ' + SCENES.map((s) => s.name).join(', '));
    }
  }
};
