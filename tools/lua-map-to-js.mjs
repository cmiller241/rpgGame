// tools/lua-map-to-js.mjs
//
// Converts maps/map01.lua (a "format 2" map written by tools/mapeditor) into
// js/maps/map01.js for the web build. Run with `npm run maps` after editing
// the map.
//
// The default export is the engine's map array, built exactly like
// src/level.lua builds level.cells:
//     mapArray[row][col] = [tileType, z, floatingBlockUnderside]
// where z = -height (negative = up) and the underside is 0 for no block.
// JS arrays are 0-based: Lua's cells[row][col][1] is mapArray[row - 1][col - 1][0].
//
// Named exports `water` ({col, row, depth} entries, 1-based like the Lua) and
// `objects` (spawn, pages, ...) carry the rest of the file.
//
// The map file is parsed with the editor's own reader (tools/mapeditor/js/
// luadata.js), so the editor, the game and this converter agree on the format.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

// luadata.js is a plain script (window.LuaData in the browser, module.exports
// in CommonJS). This package is "type": "module", so load it by hand.
function loadLuaData() {
  const src = fs.readFileSync(path.join(root, 'tools', 'mapeditor', 'js', 'luadata.js'), 'utf8');
  const mod = { exports: {} };
  new Function('module', src)(mod);
  return mod.exports;
}
const { parseFirstTable } = loadLuaData();

for (const name of ['map01']) {
  const data = parseFirstTable(fs.readFileSync(path.join(root, 'maps', name + '.lua'), 'utf8'));
  if (!data || data.format !== 2) {
    throw new Error(`${name}.lua is not a format-2 map; open and re-save it in tools/mapeditor`);
  }

  // Same as src/level.lua.
  const rows = [];
  for (let r = 0; r < data.height; r++) {
    const row = [];
    for (let c = 0; c < data.width; c++) {
      const h = (data.heights[r] && data.heights[r][c]) || 0;
      const t = (data.tiles[r] && data.tiles[r][c]) || 1;
      row.push([t, h === 0 ? 0 : -h, 0]);
    }
    rows.push(row);
  }
  for (const [c, r, underside] of data.blocks || []) {
    const cell = rows[r - 1] && rows[r - 1][c - 1];
    if (cell) cell[2] = underside;
  }

  const body = rows.map((row) => '  ' + JSON.stringify(row)).join(',\n');
  const list = (items) => (items || []).map((x) => '  ' + JSON.stringify(x)).join(',\n');
  const out = `// js/maps/${name}.js — generated from maps/${name}.lua by tools/lua-map-to-js.mjs.
// Don't edit by hand: edit the map in tools/mapeditor and run \`npm run maps\`.
//
// mapArray[row][col] = [tileType, z, floatingBlockUnderside] (0-based rows
// and columns). See js/src/tiles.js for tile types and js/src/terrain.js
// for z and floating blocks.
export default [
${body},
];

// Starting water: [col, row, depth px] (1-based, as in the Lua map).
export const water = [
${list(data.water)}
];

// Objects at pixel positions ("spawn" = player start, "page" = Bible page).
export const objects = [
${list(data.objects)}
];
`;
  fs.mkdirSync(path.join(root, 'js', 'maps'), { recursive: true });
  fs.writeFileSync(path.join(root, 'js', 'maps', name + '.js'), out);
  console.log(`lua-map-to-js: ${name} (${rows.length} rows x ${rows[0].length} columns, ` +
    `${(data.objects || []).length} objects)`);
}
