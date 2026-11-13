// player.js
//
// The player character: movement, jumping, tool use (hoe, seeds, watering
// can), picking up Bible pages, and drawing.
//
// Position: player.x / player.y are world pixels. player.y is where his feet
// are; the collision box spans x .. x+32 and y-8 .. y.
// Height uses the map's convention: player.z is NEGATIVE going up (0 =
// ground level, -32 = one tile up). player.shadowZ is the z of the ground
// under him, so (shadowZ - z) is how high he is jumping.
//
// Tiles are (col, row) from 0. player.frame counts from 1, as in the Lua
// (frame n of an animation is spriteMap...frames[n - 1]), since the tool
// animations' trigger frames and the pickup drawing use those numbers.

import love from '../love/index.js';
import canvas from './canvas.js';
import mapArray from '../maps/map01.js';
import message from './message.js';
import object from './objects.js';
import sounds from './sounds.js';
import spriteMap from '../spritemap.js';
import spriteShadow from './spriteShadow.js';
import sprites from './sprites.js';
import terrain from './terrain.js';
import water from './water.js';
import tiles from './tiles.js';
import toolbarMap from './toolbarMap.js';
import ui from './ui.js';

const player = {};
export default player;

player.spriteSheet = love.graphics.newImage('img/sprites-fixedgrid.png');
// Frames numbered from 1 (index 0 unused), as spritemap.js refers to them.
player.quads = [null];
{
  const [w, h] = player.spriteSheet.getDimensions();
  const cols = Math.ceil(w / 112);
  const rows = Math.ceil(h / 112);
  for (let i = 1; i <= rows; i++) {
    for (let j = 1; j <= cols; j++) {
      player.quads.push(love.graphics.newQuad((j - 1) * 112, (i - 1) * 112, 112, 112, w, h));
    }
  }
}

// Initial properties
player.x = 100; player.y = 250; player.z = 0; player.shadowZ = 0;
player.ax = 0; player.ay = 0; player.az = 0;   // acceleration this tick (from input)
player.vx = 0; player.vy = 0; player.vz = 0;   // velocity (vz < 0 = rising)
player.friction = 0.99; player.speed = 10; player.zSpeed = 0.5; player.speedLimit = 4;
player.jump = false;
player.jumpForce = -13;
player.gravity = 0.1;
player.gravityFactor = 250;
player.speedCharacter = 10;
player.isOnGround = true;
player.direction = 'Down';
player.state = 'Standing';
player.frame = 1;
player.frameTime = 0;
player.frameDuration = 0.2;
player.facingPage = null;      // Bible page he could pick up right now (set in update)
player.screenItem = null;      // his draw item this frame (set in addSprites)
player.screenBox = null;       // his body's screen rectangle this frame (set in addSprites)

// Tool animation tracking
player.animations = {
  Plowing: { time: 0, done: false, tileType: 56, frameTrigger: 4, canFunc: 'canPlow' },
  Sowing: { time: 0, done: false, tileType: 72, frameTrigger: -1, canFunc: 'canSow' },
  Watering: { time: 0, done: false, tileType: 73, frameTrigger: 3, canFunc: 'canWater' },
  PickUp: { time: 0, done: false, frameTrigger: 3, canFunc: 'canPickUp' },
};

// Collision box, relative to (player.x, player.y). 24 px wide to match his
// body (his side-on body is 23 px wide), centred on x + 16 like the sprite.
// 8 px tall at his feet.
const BOX_LEFT = 4, BOX_RIGHT = 27;
const BOX_TOP = -8, BOX_BOTTOM = 0;
// How tall he is (px, feet to top of hair), for floating blocks: he can walk
// under a block only if its underside is at least this far above his feet.
const PLAYER_HEIGHT = 60;

// Column of the 112 px side-facing (Left/Right) frames where his body is
// centred (body spans columns 41-63). See player.addSprites.
const SIDE_BODY_CENTRE = 52;

// The frames of his current animation.
function framesOf(state, direction) {
  return spriteMap.Cody[state][direction].frames;
}

// The tile [col, row] directly in front of the player, i.e. the one his
// tools act on.
player.getTargetTile = function () {
  const playerTileX = Math.floor((this.x + 16) / sprites.size);
  const playerTileY = Math.floor(this.y / sprites.size);
  let dx = 0, dy = 0;
  if (this.direction === 'Left') dx = -1;
  else if (this.direction === 'Right') dx = 1;
  else if (this.direction === 'Up') dy = -1;
  else if (this.direction === 'Down') dy = 1;
  return [playerTileX + dx, playerTileY + dy];
};

// Called each time a tool animation advances a frame. On the animation's
// trigger frame (e.g. the hoe hitting the ground) it changes the target tile
// once: plow grass -> dirt, sow dirt -> seeds, or water dry -> wet.
player.handleToolAnimation = function (state, frame, numFrames) {
  const anim = this.animations[state];
  if (!anim) return;
  const trigger = anim.frameTrigger === -1 ? (numFrames - 1) : anim.frameTrigger;
  if (this.frame === trigger && !anim.done) {
    if (state !== 'PickUp') {
      const [tx, ty] = this.getTargetTile();
      if (this[anim.canFunc](tx, ty)) {
        if (state === 'Watering') {
          // Watering advances dry (even) tile to wet (odd)
          mapArray[ty][tx][0] = mapArray[ty][tx][0] + 1;
        } else {
          // Plowing/Sowing use fixed tileType
          mapArray[ty][tx][0] = anim.tileType;
        }
        anim.done = true;
      }
    } else {
      anim.done = true;
    }
  }
};

// Ends a tool animation and returns to standing. Finishing a pickup opens
// the message box with the page's verse.
player.resetToolState = function (state) {
  const anim = this.animations[state];
  if (anim) {
    anim.time = 0;
    anim.done = false;
    if (state !== 'PickUp') {
      this.state = 'Standing';
      this.frame = 1;
      this.frameTime = 0;
    } else {
      message.show();
    }
  }
};

const MOVE_KEYS = [
  ['right', 1, 0, 'Right'],
  ['left', -1, 0, 'Left'],
  ['up', 0, -1, 'Up'],
  ['down', 0, 1, 'Down'],
];

// Fixed-timestep update: animation frames, tool animations, arrow-key
// movement, jumping and gravity.
player.update = function (dt) {
  if (message.isActive) return;
  this.facingPage = object.findFacing(this);    // drives the outline and the F key
  const prevState = this.state, prevDir = this.direction;
  const isToolState = this.animations[this.state];
  const current = framesOf(this.state, this.direction)[this.frame - 1];
  const frameDuration = (current && current.duration) || 5.0;
  this.frameTime = this.frameTime + dt;

  if (this.frameTime >= frameDuration) {
    this.frame = this.frame + 1;
    this.frameTime = 0;

    const numFrames = framesOf(this.state, this.direction).length;
    if (this.frame > numFrames) {
      if (isToolState) {
        this.resetToolState(this.state);
      } else {
        this.frame = 1;
      }
    } else {
      this.handleToolAnimation(this.state, this.frame, numFrames);
    }
  }

  if (isToolState) {
    const anim = this.animations[this.state];
    if (anim) {
      // Calculate total animation duration
      let totalDuration = 0;
      for (const frame of framesOf(this.state, this.direction)) {
        totalDuration = totalDuration + frame.duration;
      }
      anim.time = anim.time + dt;
      if (anim.time >= totalDuration) {
        this.resetToolState(this.state);
      }
    }
    return;
  }

  // Movement input
  this.ax = 0;
  this.ay = 0;
  let moving = false;
  for (const [key, mx, my, dir] of MOVE_KEYS) {
    if (love.keyboard.isDown(key)) {
      this.ax = mx * this.speed * dt;
      this.ay = my * this.speed * dt;
      this.direction = dir;
      moving = true;
    }
  }

  this.state = moving ? 'Walking' : 'Standing';
  if (!moving) { this.vx = 0; this.vy = 0; }

  // Jumping
  if (!this.isOnGround) {
    this.state = this.vz < 0 ? 'Jumping-Up' : 'Jumping-Down';
  }
  if (this.jump && this.isOnGround) {
    this.vz = this.jumpForce;
    this.jump = false;
    this.isOnGround = false;
  }

  // Gravity. (The ground stops him in moveCharacter, at whatever height
  // the tile under him is, including the floor of a pit.)
  this.vz = this.vz + this.gravity * this.gravityFactor * dt;

  this.vx = (this.vx + this.ax) * this.friction;
  this.vy = (this.vy + this.ay) * this.friction;
  this.vx = Math.max(-this.speedLimit, Math.min(this.vx, this.speedLimit));
  this.vy = Math.max(-this.speedLimit, Math.min(this.vy, this.speedLimit));

  const beforeX = this.x, beforeY = this.y;
  this.moveCharacter(this.vx, this.vy, this.vz * 20 * dt);

  // Pushing against a wall: stand still instead of walking on the spot
  // (the walking stride would poke his foot into the wall). The 1 px
  // check also ignores ticks where velocity is still too small to move.
  if (this.state === 'Walking' && this.x === beforeX && this.y === beforeY
      && !this.canMoveTo(this.x + (this.ax > 0 ? 1 : this.ax < 0 ? -1 : 0),
                         this.y + (this.ay > 0 ? 1 : this.ay < 0 ? -1 : 0), this.z)) {
    this.state = 'Standing';
  }

  if (this.state !== prevState || this.direction !== prevDir) {
    this.frame = 1;
    this.frameTime = 0;
  }
};

// Space starts a jump wind-up; F uses the selected tool, or picks up a
// Bible page if one is highlighted in front of the player.
player.keypressed = function (key) {
  if (key === 'space' && this.isOnGround) {
    this.state = 'Jumping-Start';
    this.direction = 'Down';
    this.frame = 1;
  } else if (key === 'f') {
    const page = object.findFacing(this);
    if (page) {
      // Pick up the Bible page in front of him and queue its message.
      message.text = page.message;
      message.verse = page.verse;
      message.tool = page.tool;
      message.toolMessage = page.toolMessage || '';
      object.remove(page);
      this.state = 'PickUp';
      this.frame = 1;
      this.frameTime = 0;
      const anim = this.animations.PickUp;
      anim.time = 0;
      anim.done = false;
      sounds.play('sow');
    } else {
      const tool = this.selectedTool();
      const [tx, ty] = this.getTargetTile();

      const triggerTool = (state, canFunc, sound) => {
        if (this[canFunc](tx, ty)) {
          this.state = state;
          this.frame = 1;
          this.frameTime = 0;
          const anim = this.animations[state];
          anim.time = 0;
          anim.done = false;
          sounds.play(sound);
        }
      };

      if (tool === 'Hoe') {
        triggerTool('Plowing', 'canPlow', 'shovel');
      } else if (tool === 'Watering Can') {
        triggerTool('Watering', 'canWater', 'water');
      } else if (tool.includes('Seed')) {
        triggerTool('Sowing', 'canSow', 'sow');
      }
    }
  } else if (key === 'w') {
    // Cast a layer of water onto the outlined tile (Hoe selected).
    if (this.selectedTool() === 'Hoe') {
      const [tx, ty] = this.getTargetTile();
      water.add(tx, ty, water.castAmount);
      sounds.play('water');
    }
  } else if (key === 'e') {
    // Place / remove a floating block over the outlined tile (Hoe selected).
    if (this.selectedTool() === 'Hoe') this.toggleBlock();
  } else if (key === 'q') {
    // Shape the land with the Hoe: Q raises, Shift+Q lowers.
    const lower = love.keyboard.isDown('lshift', 'rshift');
    this.shapeTerrain(lower ? -1 : 1);
  }
};

// Releasing space launches the jump (applied in player.update).
player.keyreleased = function (key) {
  if (key === 'space' && !this.jump && this.isOnGround) {
    this.jump = true;
  }
};

// Applies one tick of movement. Each axis (x, then y, then z) moves on its
// own, one pixel at a time, and stops at the last free pixel. So:
//   * walking into a cliff, tree or block puts him flush against it, no gap;
//   * if one axis is blocked the others still move (he slides along walls);
//   * landing on a ledge or block puts his feet exactly on top of it;
//   * jumping into the underside of a floating block stops him there and
//     he falls back down (z is negative-up, so a smaller target is "up").
player.moveCharacter = function (dx, dy, dz) {
  if (this.moveAxis('x', Math.floor(this.x + dx + 0.5))) this.vx = 0;
  if (this.moveAxis('y', Math.floor(this.y + dy + 0.5))) this.vy = 0;
  const oldZ = this.z;
  const targetZ = Math.floor(this.z + dz + 0.5);
  if (this.moveAxis('z', targetZ)) {
    this.vz = 0;
    if (targetZ > oldZ) {
      this.isOnGround = true;        // moving down and stopped: landed (or already standing)
    }                                // moving up and stopped: bumped his head
  } else if (this.z > oldZ) {
    this.isOnGround = false;         // dropping: walked off a ledge or into a pit
  }

  this.updateGround();
};

// Height of whatever he's standing on: the highest ground or floating-block
// top under any part of his collision box that's at or below his feet
// (matching canMoveTo, so standing on the edge of a block counts). Used for
// his shadow, jump height and pit focus.
player.supportHeight = function (x, y, z) {
  const ts = sprites.size;
  const feet = -z;
  let best = -Infinity;
  for (let row = Math.floor((y + BOX_TOP) / ts); row <= Math.floor((y + BOX_BOTTOM) / ts); row++) {
    for (let col = Math.floor((x + BOX_LEFT) / ts); col <= Math.floor((x + BOX_RIGHT) / ts); col++) {
      best = Math.max(best, terrain.supportAt(col, row, feet));
    }
  }
  return best;
};

player.updateGround = function () {
  this.shadowZ = -this.supportHeight(this.x, this.y, this.z);
};

// Steps this[axis] toward `target` one pixel at a time until it arrives or
// the next pixel would collide. Returns true if it was blocked. Moves are at
// most a few pixels per tick, so this is only a handful of checks.
player.moveAxis = function (axis, target) {
  const step = (target > this[axis]) ? 1 : -1;
  while (this[axis] !== target) {
    let x = this.x, y = this.y, z = this.z;
    if (axis === 'x') x = x + step;
    else if (axis === 'y') y = y + step;
    else z = z + step;

    if (!this.canMoveTo(x, y, z)) {
      return true;
    }
    this[axis] = this[axis] + step;
  }
  return false;
};

// Can the player's collision box be at (newX, newY) at height newZ? Blocked
// by the solid part of a tile (e.g. a tree trunk, see tiles.js), by any
// tile taller than newZ, by a floating block his body would overlap, and by
// the edge of the map.
//
// See BOX_LEFT etc. and PLAYER_HEIGHT at the top of this file for his size.
player.canMoveTo = function (newX, newY, newZ) {
  const left = newX + BOX_LEFT;
  const right = newX + BOX_RIGHT;
  const top = newY + BOX_TOP;
  const bottom = newY + BOX_BOTTOM;
  const feet = -newZ;
  const ts = sprites.size;

  // Every tile the box overlaps (at most 2x2).
  for (let row = Math.floor(top / ts); row <= Math.floor(bottom / ts); row++) {
    for (let col = Math.floor(left / ts); col <= Math.floor(right / ts); col++) {
      const cell = mapArray[row] && mapArray[row][col];
      if (!cell) return false;                                  // off the map
      if (cell[1] < newZ) return false;                         // taller than us
      if (tiles.blocks(col, row, left, top, right, bottom)) return false;
      // Floating block: solid from its underside b to its top; his body
      // runs from his feet to feet + PLAYER_HEIGHT.
      const b = terrain.blockAt(col, row);
      if (b != null && feet < b + terrain.blockSize && feet + PLAYER_HEIGHT > b) {
        return false;
      }
    }
  }
  return true;
};

// Tile type (v) and z at a world position. Off the map counts as an
// impassable wall (v = 9999) so the player can't walk off the edge (which
// used to crash with a nil index).
player.getTile = function (x, y) {
  const tileX = Math.floor(x / 32);
  const tileY = Math.floor(y / 32);
  const cell = mapArray[tileY] && mapArray[tileY][tileX];
  if (!cell) {
    return { v: 9999, z: 0 };
  }
  return { v: cell[0], z: cell[1] };
};

// Tool checks: each tool only works on the right tile type at the player's
// own height.
player.canPlow = function (tx, ty) {
  const tile = mapArray[ty] && mapArray[ty][tx];
  if (tile) return tile[0] === 1 && tile[1] === this.z;
  return false;
};

player.canSow = function (tx, ty) {
  const tile = mapArray[ty] && mapArray[ty][tx];
  if (tile) return tile[0] === 56 && tile[1] === this.z;
  return false;
};

player.canWater = function (tx, ty) {
  const tile = mapArray[ty] && mapArray[ty][tx];
  if (tile) return tiles.isDryCrop(tile[0]) && tile[1] === this.z;
  return false;
};

// Is a Bible page within reach and in the direction the player is facing?
player.canPickUp = function () {
  return object.findFacing(this) !== null;
};

// SMOOTH DRAWING
// Movement runs at a fixed 60 ticks/second, but the screen may refresh
// faster. Drawing his exact tick position would hold him still for a few
// frames and then jump. Instead we remember where he was at the start of
// the tick and draw him part-way between that and where he is now.
player.prevX = player.x; player.prevY = player.y; player.prevZ = player.z;
player.drawX = player.x; player.drawY = player.y; player.drawZ = player.z;

// Moves him instantly (no smoothing between old and new spot).
player.teleport = function (x, y, z) {
  this.x = x; this.y = y; this.z = z || 0;
  this.updateGround();
  this.vx = 0; this.vy = 0; this.vz = 0;
  this.rememberPosition();
  this.updateDrawPosition(1);
};

// Call at the start of every fixed update tick, before he moves.
player.rememberPosition = function () {
  this.prevX = this.x; this.prevY = this.y; this.prevZ = this.z;
};

// alpha = how far we are into the next tick (0..1). Rounded to whole pixels
// so the pixel art stays crisp.
player.updateDrawPosition = function (alpha) {
  const lerp = (a, b) => Math.floor(a + (b - a) * alpha + 0.5);
  this.drawX = lerp(this.prevX, this.x);
  this.drawY = lerp(this.prevY, this.y);
  this.drawZ = lerp(this.prevZ, this.z);
};

// Called while building the scene (see main.js). Renders his current frame
// into canvas.temp, queues his shadow, and adds a draw item.
player.addSprites = function (list, cameraX, cameraY) {
  const flipX = this.direction === 'Left' ? -1 : 1;
  const spriteNumber = framesOf(this.state, this.direction)[this.frame - 1].sprite;

  // The current frame is first drawn into a 200x200 scratch canvas
  // (canvas.temp), which is then used both to draw the player and as the
  // silhouette for his shadow. Column 100 of canvas.temp lines up with the
  // middle of his collision box (world x + 16).
  //
  // In the side-facing (Left/Right) frames his body isn't centred in the
  // 112 px frame: it spans columns 41-63, centre 52. So those frames are
  // placed with column 52 on canvas column 100, and "Left" mirrors around that
  // same column. That keeps his body inside his collision box facing either
  // way, with no jump when he turns. Up/Down frames are already centred
  // (column ~56).
  const bodyCentre = (this.direction === 'Left' || this.direction === 'Right') ? SIDE_BODY_CENTRE : 56;
  love.graphics.setCanvas(canvas.temp);
  // Origin at the body centre, so flipping mirrors around it.
  love.graphics.draw(this.spriteSheet, this.quads[spriteNumber], 100, 100 - 56, 0, flipX, 1, bodyCentre, 0);

  // In canvas.temp the feet are at row 124, centred on column 100.
  const x = this.drawX, y = this.drawY, z = this.drawZ;
  const jumpHeight = Math.max(0, this.shadowZ - z);  // px above the ground (z is negative-up)

  // No `data` field: his silhouette only exists on the GPU (canvas.temp),
  // so he casts shadows on the ground but not onto other sprites.
  const caster = {
    image: canvas.temp,
    quadX: 0, quadY: 0, quadW: 200, quadH: 200,
    anchorX: 100, anchorY: 124,
    worldX: x + 16, worldY: y - 4, worldZ: -this.shadowZ,
    lift: jumpHeight,
    opacity: 1 - jumpHeight / 320,          // shadow fades the higher he jumps
  };
  spriteShadow.add(caster);

  const item = {
    owner: this, caster,
    sortY: y - cameraY, sortX: x - cameraX,
    screenX: x - cameraX, screenY: y - cameraY, z,
    tintX: x + 16, tintY: y - 4, tintZ: -z + 24,
  };
  // Standing on (or above) a floating block under his box: draw him after
  // the row's blocks so he's on top of it, not hidden by it (main.js).
  const ts = sprites.size;
  item.drawLast = false;
  for (let row = Math.floor((y + BOX_TOP) / ts); row <= Math.floor((y + BOX_BOTTOM) / ts); row++) {
    for (let col = Math.floor((x + BOX_LEFT) / ts); col <= Math.floor((x + BOX_RIGHT) / ts); col++) {
      const b = terrain.blockAt(col, row);
      if (b != null && -z >= b + terrain.blockSize - 0.5) item.drawLast = true;
    }
  }
  list.push(item);

  // Rough screen rectangle of his body (about 28 px wide, 80 tall above
  // his feet). Trees in front of him that overlap it fade out (tree.js).
  this.screenItem = item;
  this.screenBox = {
    x0: item.screenX + 2, x1: item.screenX + 30,
    y0: item.screenY + z - 80, y1: item.screenY + z,
  };
};

// Draws the player (from canvas.temp) onto canvas.object, plus the Bible page
// he's holding during a pickup.
player.drawItem = function (item, tint) {
  const characterScreenX = item.screenX, characterScreenY = item.screenY;
  const flipX = this.direction === 'Left' ? -1 : 1;
  const flipOffsetX = 0;   // the pickup overlay below always faces Down

  love.graphics.setColor(tint, tint, tint, 1);
  // His full sprite on the x-ray canvas, which nothing ever covers. Where
  // terrain in front hides him on canvas.object, the lighting pass shows
  // this as a ghost instead (see ultimateShader.glsl).
  love.graphics.setCanvas(canvas.xray);
  love.graphics.draw(canvas.temp, characterScreenX + 16 - 100, characterScreenY - 128 + item.z);
  love.graphics.setCanvas(canvas.object);
  love.graphics.draw(canvas.temp, characterScreenX + 16 - 100, characterScreenY - 128 + item.z);

  // Draw Bible page in player's hands during PickUp animation or when message is active
  if (this.state === 'PickUp' || message.isActive) {
    this.direction = 'Down';
    let pageOffsetX = 0, pageOffsetY = 0;
    const anim = this.animations.PickUp;
    if (this.state === 'PickUp' && !message.isActive) {
      if (this.frame === 1) {
        pageOffsetX = flipX * 1; // Slightly forward, near feet
        pageOffsetY = 30; // Near ground
      } else if (this.frame === 2) {
        pageOffsetX = flipX * 1; // Near chest
        pageOffsetY = 10; // Chest level
      } else if (this.frame === 3) {
        pageOffsetX = flipX * 1; // Centered above head
        const frameStartTime = 0.125 + 0.125; // Time when frame 3 starts
        const t = Math.min((anim.time - frameStartTime) / 1.0, 1.0); // Normalized time (0 to 1)
        pageOffsetY = -40 + t * (-60 - (-40)); // Linear interpolation from -40 to -60
      }
    } else {
      // Message is active, draw Bible page at final position
      pageOffsetX = flipX * 1;
      pageOffsetY = -60;
    }
    love.graphics.draw(
      sprites.objects,
      sprites.biblePageCenter,
      characterScreenX + 16 - 32 + pageOffsetX,
      characterScreenY - 64 + item.z + pageOffsetY,
      0,
      1,
      1,
      0,
      0,
    );
    if (this.frame === 2 && this.direction === 'Down') {
      love.graphics.draw(this.spriteSheet, this.quads[97], characterScreenX + 16 - 55, characterScreenY - 84 + item.z, 0, flipX, 1, flipOffsetX, 0);
    }
  }
  love.graphics.setColor(1, 1, 1, 1);
};

// Name of the tool in the highlighted toolbar slot (e.g. "Hoe", "Empty").
player.selectedTool = function () {
  return toolbarMap.slots[toolbarMap.visibleSlots[ui.highlightedSlot]].name;
};

// FLOATING BLOCKS (E with the Hoe selected)
// Places a block over the outlined tile, BLOCK_GAP px above its ground, or
// removes the block that's there. Refused if it would trap the player.
// His jump peaks at ~65 px, so with a 24 px gap the block's top (56 px) is
// comfortably reachable. To walk UNDER a block its underside must be at least
// PLAYER_HEIGHT (60 px) up; such blocks can only be reached from higher ground.
const BLOCK_GAP = 24;

player.toggleBlock = function () {
  const [tx, ty] = this.getTargetTile();
  if (!(mapArray[ty] && mapArray[ty][tx])) return;
  if (terrain.blockAt(tx, ty) != null) {
    terrain.setBlock(tx, ty, null);
  } else {
    terrain.setBlock(tx, ty, terrain.heightAtTile(tx, ty) + BLOCK_GAP);
    if (!this.canMoveTo(this.x, this.y, this.z)) {
      terrain.setBlock(tx, ty, null);              // would trap him: undo
      return;
    }
  }
  sounds.play('shovel');
};

// TERRAIN SHAPING (Q / Shift+Q with the Hoe selected)
// Raises (direction = 1) or lowers (direction = -1) the tile in front of the
// player by one level. Heights stay between -MAX_DEPTH (a pit) and MAX_RAISE.
// Refused if the new height would put the player inside the tile (his
// collision box can overlap the target tile when he faces sideways).
const RAISE_STEP = 32;                 // one tile
const MAX_RAISE  = 10 * RAISE_STEP;    // tallest a player-made mountain can get
const MAX_DEPTH  = 5 * RAISE_STEP;     // deepest a pit can get (deeper only shows more back wall)

player.shapeTerrain = function (direction) {
  if (this.selectedTool() !== 'Hoe') return;
  const [tx, ty] = this.getTargetTile();
  const cell = mapArray[ty] && mapArray[ty][tx];
  if (!cell) return;

  const oldHeight = -cell[1];
  const newHeight = Math.max(-MAX_DEPTH, Math.min(MAX_RAISE, oldHeight + direction * RAISE_STEP));
  if (newHeight === oldHeight) return;
  // Ground can't rise into a floating block above it.
  const block = terrain.blockAt(tx, ty);
  if (block != null && newHeight > block) return;

  terrain.setTileHeight(tx, ty, newHeight);
  if (!this.canMoveTo(this.x, this.y, this.z)) {
    terrain.setTileHeight(tx, ty, oldHeight);   // would trap him: undo
    return;
  }
  sounds.play('shovel');
};

// Outline on the tile in front of the player:
//   yellow  the selected tool can be used there (plow / sow / water)
//   white   Hoe selected but the tile can't be plowed: shows which tile
//           Q / Shift+Q will raise or lower
player.drawOutline = function (cameraX, cameraY, mapArray) {
  if (this.facingPage) return;   // the page's outline takes priority

  const tool = this.selectedTool();
  const isSeed = tool.includes('Seed');
  if (tool !== 'Hoe' && !isSeed && tool !== 'Watering Can') return;

  const [tx, ty] = this.getTargetTile();
  const cell = mapArray[ty] && mapArray[ty][tx];
  if (!cell) return;

  const usable = (tool === 'Hoe' && this.canPlow(tx, ty)) ||
                 (isSeed && this.canSow(tx, ty)) ||
                 (tool === 'Watering Can' && this.canWater(tx, ty));

  if (usable) {
    love.graphics.setColor(1, 1, 0, 1);
  } else if (tool === 'Hoe') {
    love.graphics.setColor(1, 1, 1, 0.8);
  } else {
    return;
  }

  love.graphics.setCanvas(canvas.offscreen);
  const x = tx * sprites.size - cameraX;
  const y = ty * sprites.size - cameraY;
  love.graphics.rectangle('line', x, y + cell[1], sprites.size, sprites.size);
  love.graphics.setColor(1, 1, 1, 1);
};
