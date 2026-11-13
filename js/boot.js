// boot.js
//
// The web build's entry point (bundled into dist/bundle.js by esbuild).
//
// LÖVE loads files synchronously, and the game's modules load their images,
// sounds and shaders as soon as they're imported (as the Lua modules do
// when required). A browser can't, so this preloads everything listed in
// js/assetList.js first, and only then imports main.js and the game.

import love from './love/index.js';
import assetList from './assetList.js';

// Pixel art: images must be loaded with nearest-neighbour filtering, so set
// the default before any module loads an image (main.lua's first line).
love.graphics.setDefaultFilter('nearest', 'nearest');

// The page's query string stands in for LÖVE's command-line arguments:
// ?shots -> "--shots", ?scene=water_pools -> "--scene=water_pools".
const args = [];
for (const [key, value] of new URLSearchParams(location.search)) {
  args.push(value ? `--${key}=${value}` : `--${key}`);
}

love.boot({
  canvas: document.getElementById('gameCanvas'),
  images: assetList.images,
  sounds: assetList.sounds,
  texts: assetList.texts,
  fonts: assetList.fonts,
  beforeLoad: () => import('./main.js'),
  args,
});
