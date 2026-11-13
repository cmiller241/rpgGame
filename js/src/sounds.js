// sounds.js

import love from '../love/index.js';

const sounds = {};
export default sounds;

// Load sound
sounds.shovel = love.audio.newSource('sound/085296_shovel-36732.mp3', 'static');
sounds.jump = love.audio.newSource('sound/8-bit-jump-001-171817.mp3', 'static');

// Random decimal between lo and hi. (love.math.random(lo, hi) only returns
// whole-number steps from lo, so love.math.random(0.9, 1.1) gives 0.9 or 1.9.)
function randomBetween(lo, hi) {
  return lo + love.math.random() * (hi - lo);
}

// Plays a sound (falls back to the shovel if `name` doesn't exist yet) with a
// little random pitch and volume variation so repeats don't sound robotic.
sounds.play = function (name) {
  const source = (name !== 'play' && sounds[name]) || sounds.shovel;
  const s = source.clone();
  s.setPitch(randomBetween(0.9, 1.1));
  s.setVolume(randomBetween(0.8, 1.0));
  s.play();
};
