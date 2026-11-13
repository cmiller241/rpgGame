// tree.js
//
// Oak (tile 512) and pine (tile 520) trees. Both live in img/tree4.png as
// 480x480 quads. Each tree is drawn with the wind-sway shader and casts a
// shadow that sways in step with its canopy.

import love from '../love/index.js';
import canvas from './canvas.js';
import player from './player.js';
import shader from './shader.js';
import spriteShadow from './spriteShadow.js';
import sprites from './sprites.js';

const tree = {};
export default tree;

// Per kind: which quad, and the point in that quad (anchorX, anchorY) where
// the tree meets the ground. That point is placed at BASE_IN_TILE inside the
// tile, so both kinds stand in the same spot.
const KINDS = {
  oak:  { quad: sprites.treeTrunk, anchorX: 240, anchorY: 250 },
  pine: { quad: sprites.pineTree,  anchorX: 244, anchorY: 258 },
};
const BASE_IN_TILE_X = 16, BASE_IN_TILE_Y = 26;

// Wind: max sideways shift at the treetop (px) and speed.
const WIND_PX = 5, WIND_SPEED = 3.0;
// Where the bend starts, as a fraction down the 480 px quad (trunk base ~0.52).
const SWAY_ANCHOR_V = 0.55;
// Height (px above the base) used to decide if a tree is in shadow: mid-canopy.
const TINT_SAMPLE_HEIGHT = 110;

// SEE-THROUGH TREES
// A tree in front of the player that overlaps him fades to FADE_ALPHA so
// you can see him (and the ground) behind it, easing in and out at
// FADE_SPEED (alpha per second). Its shadow is unaffected.
tree.FADE_ALPHA = 1;
tree.FADE_SPEED = 4;
// Rough screen-space extent of the canopy around the base point.
const CANOPY_HALF_WIDTH = 76, CANOPY_HEIGHT = 220, CANOPY_BOTTOM = 0;

// Current alpha of each tree that's fading, by tile ("col,row").
const fade = new Map();

// Is this tree drawn in front of the player and covering part of him?
function coversPlayer(item) {
  const p = player.screenItem, box = player.screenBox;
  if (!p || item.sortY <= p.sortY) return false;   // behind him
  return item.drawX + CANOPY_HALF_WIDTH > box.x0 && item.drawX - CANOPY_HALF_WIDTH < box.x1
      && item.drawY - CANOPY_HEIGHT < box.y1 && item.drawY + CANOPY_BOTTOM > box.y0;
}

// Eases this tree's alpha toward its target and returns it.
function fadeAlpha(item) {
  const target = coversPlayer(item) ? tree.FADE_ALPHA : 1;
  let a = fade.get(item.key) ?? 1;
  const step = tree.FADE_SPEED * love.timer.getDelta();
  if (a < target) a = Math.min(target, a + step); else a = Math.max(target, a - step);
  if (a < 1) fade.set(item.key, a); else fade.delete(item.key);   // forget trees that are fully solid again
  return a;
}

// Called while building the scene (see main.js). Queues the tree's shadow
// and adds a draw item to `list`.
tree.addSprites = function (list, kind, xC, yC, z, screenX, screenY) {
  const k = KINDS[kind];
  const ts = sprites.size;
  const [qx, qy, qw, qh] = k.quad.getViewport();

  const baseX = xC * ts + BASE_IN_TILE_X;
  const baseY = yC * ts + BASE_IN_TILE_Y;
  const baseZ = -z;

  // One sway value for this frame, shared by the canopy and its shadow.
  // The phase differs per tile so neighbouring trees don't move in unison.
  // (xC + 1, yC + 1: the Lua's 1-based tile numbers, so trees sway in the
  // same phase as in the LÖVE build.)
  const swayPx = Math.sin(love.timer.getTime() * WIND_SPEED + (xC + 1) * 1.7 + (yC + 1) * 0.6) * WIND_PX;

  const caster = {
    image: sprites.tree, data: sprites.treeData,
    quadX: qx, quadY: qy, quadW: qw, quadH: qh,
    anchorX: k.anchorX, anchorY: k.anchorY,
    worldX: baseX, worldY: baseY, worldZ: baseZ,
    castLamp: true,
    swayPx, swayAnchor: SWAY_ANCHOR_V,
  };
  spriteShadow.add(caster);

  list.push({
    owner: this, caster, kind: k, swayPx, key: xC + ',' + yC,
    sortY: screenY + BASE_IN_TILE_Y, sortX: screenX,
    drawX: screenX + BASE_IN_TILE_X, drawY: screenY + BASE_IN_TILE_Y + z,
    tintX: baseX, tintY: baseY, tintZ: baseZ + TINT_SAMPLE_HEIGHT,
  });
};

// Draws a tree item onto canvas.object with brightness `tint`.
tree.drawItem = function (item, tint) {
  const k = item.kind;
  const [, qy, , qh] = k.quad.getViewport();
  const [texW, texH] = sprites.tree.getDimensions();

  const s = shader.windSway;
  love.graphics.setCanvas(canvas.object);
  love.graphics.setShader(s);
  s.send('sway', item.swayPx / texW);
  s.send('quadV0', qy / texH);
  s.send('quadV1', (qy + qh) / texH);
  s.send('anchorV', SWAY_ANCHOR_V);
  love.graphics.setColor(tint, tint, tint, fadeAlpha(item));
  love.graphics.draw(sprites.tree, k.quad, item.drawX, item.drawY, 0, 1, 1, k.anchorX, k.anchorY);
  love.graphics.setColor(1, 1, 1, 1);
  love.graphics.setShader();
};
