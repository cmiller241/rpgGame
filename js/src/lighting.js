// lighting.js
//
// Per-frame light state (sun + the player's lamp) and the final composite
// pass that turns the ground, sprite and shadow canvases into the finished
// frame. The heavy lifting is in shaders/ultimateShader.glsl.

import love from '../love/index.js';
import canvas from './canvas.js';
import player from './player.js';
import shader from './shader.js';
import spriteShadow from './spriteShadow.js';
import sprites from './sprites.js';
import sun from './sun.js';
import terrain from './terrain.js';
import water from './water.js';

const lighting = {};
export default lighting;

lighting.lampRadius = 100;    // px, how far the player's lamp reaches
lighting.lampHeight = 24;     // px above the player's feet (roughly hand height)

// How visible the player's silhouette is through terrain that hides him
// (pit rims, cliffs in front of him). 0 turns the ghost off.
lighting.ghostOpacity = 0.2;

// PIT FOCUS
// While the player stands below ground level (in a pit), the pit gets the
// attention:
//   * higher terrain that hides part of the pit (e.g. its front rim) turns
//     partly see-through, showing the pit floor and the player under it;
//   * all other terrain and sprites above his level are dimmed a little.
// The tiles at/below his level are rendered as a separate layer for this
// (main.js, terrain.drawFocusSurface). Eases in and out.
lighting.focusRevealOpacity = 0.5;    // how much of the pit shows through higher ground (0..1)
lighting.focusPlayerOpacity = 0.85;   // how much of the player shows through it (0..1)
lighting.focusDim           = 0.2;    // how much darker/greyer everything above his level gets (0..1)
lighting.focusFadeTime      = 0.25;   // seconds to ease in / out

// Current focus state (updated in lighting.begin).
lighting.focus = { amount: 0, level: 0 };

// Filled in by lighting.begin() each frame.
lighting.sun = null;
lighting.lamp = { x: 0, y: 0, z: 0, radius: lighting.lampRadius };

// Call once at the start of love.draw, before any sprites are drawn.
lighting.begin = function () {
  this.sun = sun.getState();

  // Pit focus: on while the ground under him is below ground level. When he
  // climbs out, keep the old level until the effect has faded away.
  const focus = this.focus;
  const groundLevel = -player.shadowZ;
  if (groundLevel < 0) focus.level = groundLevel;
  const target = (groundLevel < 0) ? 1 : 0;
  const step = love.timer.getDelta() / Math.max(this.focusFadeTime, 1e-6);
  if (focus.amount < target) {
    focus.amount = Math.min(target, focus.amount + step);
  } else {
    focus.amount = Math.max(target, focus.amount - step);
  }

  // The lamp sits at the player's feet position on the ground plane, raised
  // to hand height. player.z is negative-up, so -player.z is the height.
  const lamp = this.lamp;
  lamp.x = player.drawX + 16;
  lamp.y = player.drawY - 4;
  lamp.z = -player.drawZ + this.lampHeight;
  lamp.radius = this.lampRadius;
};

// Brightness multiplier for a sprite sampled at world (wx, wy), height h:
// the same lit/shadow level the shader gives the ground, so sprites darken
// in a cliff's shadow or another sprite's shadow (e.g. under a tree) and
// fade into dusk along with everything else. `ownCaster` is the sprite's own
// shadow caster, so it doesn't shadow itself. Use with love.graphics.setColor.
lighting.objectTint = function (wx, wy, h, ownCaster) {
  const sunState = this.sun;
  if (sunState.litLevel <= sunState.shadowLevel) {
    return sunState.litLevel;                 // no direct sun to block
  }
  let shade = terrain.sunShadowAmount(wx, wy, h, sunState);
  if (shade < 1) {
    shade = Math.max(shade, spriteShadow.sunShadowAt(wx, wy, h, ownCaster, sunState));
  }
  return sunState.litLevel + (sunState.shadowLevel - sunState.litLevel) * shade;
};

// Composites canvas.offscreen (+ object/shadow canvases) into
// canvas.intermediate with lighting, shadows and colour grading applied.
lighting.composite = function (cameraX, cameraY) {
  const s = shader.ultimate, sunState = this.sun, lamp = this.lamp;

  love.graphics.setCanvas(canvas.intermediate);
  love.graphics.setShader(s);

  terrain.sendUniforms(s, cameraX, cameraY);
  s.send('objectCanvas', canvas.object);
  s.send('shadowCanvas', canvas.shadow);
  s.send('xrayCanvas', canvas.xray);
  s.send('ghostOpacity', this.ghostOpacity);

  s.send('focusCanvas', canvas.focus);
  s.send('focusSurfaceMap', canvas.focusSurface);
  s.send('focusAmount', this.focus.amount);
  s.send('focusLevel', this.focus.level);
  s.send('focusRevealOpacity', this.focusRevealOpacity);
  s.send('focusPlayerOpacity', this.focusPlayerOpacity);
  s.send('focusDim', this.focusDim);
  s.send('time', love.timer.getTime());
  s.send('waterMap', water.map);

  // Player in water: how deep it is at his feet, and where the surface
  // line falls on screen (his feet are 4 px above player.y in the art).
  const feetScreenY = player.drawY - 4 + player.drawZ - cameraY;
  const depthAtFeet = water.depthAtFeet(player.drawX + 16, player.drawY - 4, -player.drawZ);
  s.send('playerWaterDepth', depthAtFeet);
  s.send('playerWaterLine', feetScreenY - depthAtFeet);

  s.send('sunDir', [sunState.dirX, sunState.dirY]);
  s.send('sunSlope', sunState.slope);
  s.send('sunSoftness', sunState.softness);
  s.send('litLevel', sunState.litLevel);
  s.send('shadowLevel', sunState.shadowLevel);
  s.send('faceLight', sunState.faceLight);

  s.send('lampPos', [lamp.x, lamp.y, lamp.z]);
  s.send('lampScreen', [lamp.x - cameraX, lamp.y - lamp.z - cameraY]);
  s.send('lampRadius', lamp.radius);

  s.send('lutImage', sprites.lut);
  s.send('lutSize', sprites.lut.getDimensions());
  s.send('lutRowA', sunState.lutRowA);
  s.send('lutRowB', sunState.lutRowB);
  s.send('lutMix', sunState.lutMix);

  love.graphics.draw(canvas.offscreen, 0, 0);
  love.graphics.setShader();
};
