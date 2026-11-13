// objects.js
//
// The Bible pages lying around the world, waiting to be picked up.

import love from '../love/index.js';
import canvas from './canvas.js';
import player from './player.js';
import shader from './shader.js';
import spriteShadow from './spriteShadow.js';
import sprites from './sprites.js';
import terrain from './terrain.js';
import { objects as mapObjects } from '../maps/map01.js';

const object = {};
export default object;

// The Bible pages, placed with the map editor (objects of type "page" in the
// map file). Each is copied so the game can add runtime fields.
object.objects = mapObjects
  .filter((obj) => obj.type === 'page')
  .map((obj) => ({ ...obj, animationTime: 0 }));

// How close (px) the player must be to pick a page up.
object.reach = 50;

// The nearest page within reach that the player is facing, or null.
// "Facing" means the page is on the side he's looking toward.
object.findFacing = function (p) {
  let best = null, bestDist = this.reach;
  for (const obj of this.objects) {
    const dx = obj.x - p.x, dy = obj.y - p.y;
    const dist = Math.sqrt(dx * dx + dy * dy);
    const facing = (p.direction === 'Up' && dy < 0) || (p.direction === 'Down' && dy > 0)
                || (p.direction === 'Left' && dx < 0) || (p.direction === 'Right' && dx > 0);
    if (facing && dist < bestDist) {
      best = obj;
      bestDist = dist;
    }
  }
  return best;
};

object.remove = function (obj) {
  const i = this.objects.indexOf(obj);
  if (i >= 0) this.objects.splice(i, 1);
};

// Map row (0-based) a page belongs to for draw ordering: the row its
// ground point is in.
object.rowOf = function (obj) {
  return Math.floor((obj.y - 4) / sprites.size);
};

// Called while building the scene (see main.js). Queues the page's shadow
// and adds a draw item. The 64x64 sprite is drawn with its bottom-centre at
// (obj.x, obj.y), bobbing up and down.
object.addSprites = function (list, obj, cameraX, cameraY) {
  const groundX = obj.x, groundY = obj.y - 4;
  const groundH = terrain.heightAtWorld(groundX, groundY);
  // Bob up and down: 1 s period, 4 px amplitude.
  const yOffset = Math.sin(obj.animationTime * 2 * Math.PI) * 4;

  // Its bottom row (60) hovers 4 px above the ground at rest.
  const [qx, qy, qw, qh] = sprites.biblePageCenter.getViewport();
  const caster = {
    image: sprites.objects, data: sprites.objectsData,
    quadX: qx, quadY: qy, quadW: qw, quadH: qh,
    anchorX: 32, anchorY: 60,
    worldX: groundX, worldY: groundY, worldZ: groundH,
    lift: 4 - yOffset,
  };
  spriteShadow.add(caster);

  list.push({
    owner: this, caster, obj,
    sortY: groundY - cameraY, sortX: groundX - cameraX,
    drawX: obj.x - 32 - cameraX, drawY: obj.y - 64 - cameraY + yOffset - groundH,
    tintX: groundX, tintY: groundY, tintZ: groundH + 30,
  });
};

// Draws a page item, outlined if it's the one the player can pick up.
object.drawItem = function (item, tint) {
  love.graphics.setCanvas(canvas.object);
  if (item.obj === player.facingPage) {
    love.graphics.setShader(shader.outline);
  }
  love.graphics.setColor(tint, tint, tint, 1);
  love.graphics.draw(sprites.objects, sprites.biblePageCenter, item.drawX, item.drawY);
  love.graphics.setColor(1, 1, 1, 1);
  love.graphics.setShader();
};
