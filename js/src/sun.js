// sun.js
//
// The sun drives every time-of-day effect: shadow direction and length,
// shadow darkness, how brightly cliff faces are lit, and which colour-grading
// LUT is used.
//
// `sun.angle` is a single number in degrees that runs 0 -> 360 over one day:
//
//     0   sunrise (sun on the eastern horizon, +x)
//     90  noon    (sun high in the south, toward the camera, +y)
//     180 sunset  (sun on the western horizon, -x)
//     180-360     night (no sun shadows)
//
// The angle doubles as the sun's compass direction (azimuth) in screen space:
// (cos(angle), sin(angle)) points from the ground TOWARD the sun. Its height
// in the sky (altitude) rises and falls with sin(angle), from `minAltitude`
// at sunrise/sunset to `maxAltitude` at noon. Altitude decides shadow length:
// something H px tall casts a shadow H / tan(altitude) px long. Keeping
// minAltitude at 45 degrees (tan = 1) means a shadow is never longer than the
// height of whatever casts it.

import love from '../love/index.js';
import { mod } from '../love/lua.js';

const sun = {};
export default sun;

const rad = (deg) => deg * Math.PI / 180;

sun.angle         = 0;
sun.rotationSpeed = 30;                 // degrees/second while holding M or N (debug)
sun.dayLength     = 1200;               // seconds for one full day/night cycle (20 min)
sun.maxAltitude   = rad(75);            // noon: shadows ~0.27x the caster's height
sun.minAltitude   = rad(45);            // sunrise/sunset: shadows exactly 1x height (never longer)

// Shadow softness: the sun's apparent size (in radians-ish). A shadow edge
// blurs by about `softness` px for every px it is from whatever casts it,
// so shadows stay crisp where they touch the caster and soften with
// distance. 0 = razor-sharp pixel edges; 0.08 = gently soft; 0.15+ = very soft.
sun.softness      = 0.02;

// LIGHT LEVELS
// Light is split in two: AMBIENT (sky light, reaches everything) and DIRECT
// (the sun itself, blocked by anything casting a shadow).
//   shadowed pixel = ambient
//   sunlit pixel   = ambient + direct
// Shadows never fade out while the scene stays bright. Over the last
// `twilightDegrees` before sunset, sunlit and shadowed levels both move
// to `twilightLevel` and meet at sunset. Because the colour grade (LUT) is
// darkening fast at the same time, sunlit ground gets steadily darker and
// shadowed ground never gets brighter on screen. The shadows sink into the
// dusk rather than turning see-through.
//
// twilightLevel was picked by running grass through the LUT across the day:
//   * at the ambient level (0.505) sunset went nearly black, darker than night
//   * at 1.0, shadowed ground brightened 11 -> 28 (out of 100) before sunset
//   * at 0.65, sunlit falls 39 -> 23 -> 11 -> 8, shadowed holds 11 -> 9 -> 8,
//     and sunset (8) blends straight into night (9)
//
// After sunset the level eases from twilightLevel to 1.0 over
// `nightRecoveryDegrees` while the LUT blends dusk -> night, so nights look
// the same as before. Dawn mirrors all of this.
sun.ambientLevel         = 0.505;  // shadowed ground at full day (sunlit = 1.0)
sun.twilightLevel        = 0.65;   // where sunlit and shadowed levels meet at sunset/sunrise
sun.twilightDegrees      = 30;     // how long before sunset (after sunrise) the sun dims
sun.nightRecoveryDegrees = 80;     // matches the LUT's dusk->night / night->dawn blend

// Cliff-face brightness multipliers (see sun.getState). All visible faces
// point south, so they're lit by how squarely the sun faces them: dim when
// it's off to the east/west, full at noon. Tops are handled by the LUT alone.
sun.faceLightMin   = 0.70;              // sun on the east/west horizon (grazing the wall)
sun.faceLightMax   = 1.00;              // sun due south at noon (art unchanged)
sun.faceLightNight = 0.70;              // faces at night (same as sunset, so no jump)

// The LUT image (img/LUD2.png) stacks four 32-row colour grades vertically.
// These are the row each block starts on.
const LUT_NOON = 0, LUT_DUSK = 32, LUT_NIGHT = 64, LUT_DAWN = 96;

// Re-used every frame so getState doesn't allocate.
const state = {};

sun.update = function (dt) {
  // Continuous day/night progression.
  this.angle = this.angle + (360 / this.dayLength) * dt;

  // Debug: scrub time of day.
  if (love.keyboard.isDown('m')) {
    this.angle = this.angle + this.rotationSpeed * dt;
  }
  if (love.keyboard.isDown('n')) {
    this.angle = this.angle - this.rotationSpeed * dt;
  }

  this.angle = mod(this.angle, 360);  // (Lua's %: 0..360 even for negatives)
};

// Picks the two LUT blocks to blend between and how far along the blend we are.
// Returns [rowA, rowB, t]  (final colour = mix(LUT[rowA], LUT[rowB], t)).
//
//     0 -  80   dawn  -> noon
//    80 - 100   noon (hold)
//   100 - 180   noon  -> dusk
//   180 - 260   dusk  -> night
//   260 - 280   night (hold)
//   280 - 360   night -> dawn
sun.getLutBlend = function (a) {
  if (a <= 80) {
    return [LUT_DAWN, LUT_NOON, a / 80];
  } else if (a <= 100) {
    return [LUT_NOON, LUT_NOON, 0];
  } else if (a <= 180) {
    return [LUT_NOON, LUT_DUSK, (a - 100) / 80];
  } else if (a <= 260) {
    return [LUT_DUSK, LUT_NIGHT, (a - 180) / 80];
  } else if (a <= 280) {
    return [LUT_NIGHT, LUT_NIGHT, 0];
  } else {
    return [LUT_NIGHT, LUT_DAWN, (a - 280) / 80];
  }
};

// Everything the renderer needs to know about the sun this frame.
//
//   isUp            true between sunrise and sunset
//   dirX, dirY      unit vector on the ground plane pointing toward the sun
//   slope           tan(altitude): how many pixels a sun ray climbs per pixel
//                   travelled across the ground
//   softness        see sun.softness
//   litLevel        brightness multiplier for sunlit pixels (ambient + direct)
//   shadowLevel     brightness multiplier for shadowed pixels (ambient only)
//                   litLevel == shadowLevel means there's no direct sun, so
//                   shadows don't need computing at all.
//   faceLight       brightness multiplier for south-facing cliff faces
//   lutRowA/B, lutMix   colour-grade blend (see getLutBlend)

// 0 -> 1 with an S-curve (eases in and out) as x goes from 0 to 1.
function smoothstep(x) {
  x = Math.max(0, Math.min(1, x));
  return x * x * (3 - 2 * x);
}

sun.getState = function () {
  const a = mod(this.angle, 360);
  const r = rad(a);

  state.isUp = a > 0 && a < 180;
  state.dirX = Math.cos(r);
  state.dirY = Math.sin(r);

  const altitude = this.minAltitude
    + (this.maxAltitude - this.minAltitude) * Math.max(0, Math.sin(r));
  state.slope = Math.tan(altitude);
  state.softness = this.softness;

  if (state.isUp) {
    // day = 0 at the horizon, 1 once the sun is twilightDegrees up.
    // Lit and shadowed levels move from their full-day values (1.0 and
    // ambientLevel) to meet at twilightLevel as day -> 0.
    const degreesFromHorizon = Math.min(a, 180 - a);
    const day = smoothstep(degreesFromHorizon / this.twilightDegrees);
    const tw = this.twilightLevel;
    state.litLevel    = tw + (1 - tw) * day;
    state.shadowLevel = tw + (this.ambientLevel - tw) * day;

    // dirY = sin(azimuth): 0 when the sun is due east/west, 1 when it's
    // due south, i.e. how directly it faces a south-pointing wall.
    const facing = Math.max(0, state.dirY);
    state.faceLight = this.faceLightMin + (this.faceLightMax - this.faceLightMin) * facing;
  } else {
    // Night: no direct light. Ease from twilightLevel back to 1.0 as the
    // LUT takes over the darkening (and back down before sunrise).
    const degreesFromHorizon = Math.min(a - 180, 360 - a);
    const recovery = smoothstep(degreesFromHorizon / this.nightRecoveryDegrees);
    const level = this.twilightLevel + (1 - this.twilightLevel) * recovery;
    state.shadowLevel = level;
    state.litLevel = level;
    state.faceLight = this.faceLightNight;
  }

  [state.lutRowA, state.lutRowB, state.lutMix] = this.getLutBlend(a);
  return state;
};
