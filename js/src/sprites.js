// sprites.js
//
// Every image the game draws, and the quads cut from them.
//
// The quad lists (spritesQuads, cropQuads, toolbarQuads, objectQuads) are
// numbered from 1 like the Lua tables (index 0 is unused): tile types,
// spritemap sprite numbers and toolbar tool numbers in the game's data all
// refer to quads by those numbers.

import love from '../love/index.js';

const sprites = {};
export default sprites;

// Load images

// The ground tile sheet. Floating-block art (img/block.png: 32x64, top face
// above front face) is appended underneath it at load time, so blocks can
// go in the same tile batch as everything else (one texture per batch).
// Existing tile numbers are unchanged; see sprites.blockTopQuad below.
{
  const sheet = love.image.newImageData('img/sprites2.png');
  const block = love.image.newImageData('img/block.png');
  const combined = love.image.newImageData(sheet.getWidth(), sheet.getHeight() + block.getHeight());
  combined.paste(sheet, 0, 0, 0, 0, sheet.getWidth(), sheet.getHeight());
  combined.paste(block, 0, sheet.getHeight(), 0, 0, block.getWidth(), block.getHeight());
  sprites.land = love.graphics.newImage(combined);
  sprites.blockSheetY = sheet.getHeight();   // where the block art starts in sprites.land
}
sprites.crop = love.graphics.newImage('img/crop.png');
// All ground tiles for a frame (grass, dirt, cliff faces) go into this one
// batch and are drawn in a single call. Grows automatically if needed.
sprites.tileBatch = love.graphics.newSpriteBatch(sprites.land, 1600);
// While the player is down in a pit, the tiles at or below his level are
// also drawn into this batch, as a separate layer the lighting pass can
// show through higher ground (see lighting.js, "pit focus").
sprites.focusBatch = love.graphics.newSpriteBatch(sprites.land, 400);
sprites.grass = love.graphics.newImage('img/grass3.png');
sprites.tree = love.graphics.newImage('img/tree4.png');
sprites.grungeOverlay = love.graphics.newImage('img/grunge3.jpg');
// Colour-grading lookup table: four 32-row blocks (noon, dusk, night, dawn).
// Must be sampled exactly, never blurred.
sprites.lut = love.graphics.newImage('img/LUD2.png');
sprites.lut.setFilter('nearest', 'nearest');
sprites.toolbar = love.graphics.newImage('img/toolbar.png');
sprites.objects = love.graphics.newImage('img/objects.png');
sprites.parchment = love.graphics.newImage('img/parchment.png');
sprites.textbox = love.graphics.newImage('img/textbox.png');
sprites.size = 32;

// CPU-readable copies of the sprite sheets that cast shadows, so the game
// can check whether one sprite is standing in another's shadow (see
// spriteShadow.sunShadowAt).
sprites.treeData    = love.image.newImageData('img/tree4.png');
sprites.cropData    = love.image.newImageData('img/crop.png');
sprites.objectsData = love.image.newImageData('img/objects.png');

// Cuts `image` into a grid of size x size quads, numbered from 1
// left-to-right, top-to-bottom (index 0 unused).
function gridQuads(image, w, h) {
  const quads = [null];
  const cols = Math.ceil(image.getWidth() / w);
  const rows = Math.ceil(image.getHeight() / h);
  const [iw, ih] = image.getDimensions();
  for (let i = 1; i <= rows; i++) {
    for (let j = 1; j <= cols; j++) {
      quads[(i - 1) * cols + j] = love.graphics.newQuad((j - 1) * w, (i - 1) * h, w, h, iw, ih);
    }
  }
  return quads;
}

// Load quads for general sprites
sprites.spritesQuads = gridQuads(sprites.land, sprites.size, sprites.size);

// Floating block faces (see the note at the top of this file).
sprites.blockTopQuad   = love.graphics.newQuad(0, sprites.blockSheetY, 32, 32, ...sprites.land.getDimensions());
sprites.blockFrontQuad = love.graphics.newQuad(0, sprites.blockSheetY + 32, 32, 32, ...sprites.land.getDimensions());

// Load quads for crops
sprites.cropQuads = gridQuads(sprites.crop, 112, 112);

// Load quads for toolbar sprites
sprites.toolbarQuads = gridQuads(sprites.toolbar, 60, 60);

// Create quads for tree and grass
sprites.grassQuad = love.graphics.newQuad(0, 0, 32, 27, ...sprites.grass.getDimensions());
sprites.treeTrunk = love.graphics.newQuad(0, 0, 480, 480, ...sprites.tree.getDimensions());
sprites.treeFoliage = love.graphics.newQuad(480, 0, 480, 480, ...sprites.tree.getDimensions());
sprites.pineTree = love.graphics.newQuad(960, 0, 480, 480, ...sprites.tree.getDimensions());

// Load quads for objects spritesheet (640x640, 64x64 tiles)
sprites.objectQuads = gridQuads(sprites.objects, 64, 64);

// Bible page animation frame
sprites.biblePageCenter = sprites.objectQuads[1]; // First frame: centered
