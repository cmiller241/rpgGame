// spritemap.js
//
// The player's (Cody's) animations: for each state and facing direction,
// its frames in order. `sprite` is a frame number in
// img/sprites-fixedgrid.png (player.quads, numbered from 1); `duration` is
// in seconds. (player.frame counts from 1 too, so frame n is frames[n - 1].)

const f = (sprite, duration) => ({ sprite, duration });
const one = (sprite) => ({ frames: [f(sprite, 0.2)] });

const spriteMap = {
  Cody: {
    Standing: {
      Down: { frames: [f(1, 0.2), f(1, 0.2), f(2, 0.2), f(3, 0.2), f(2, 0.2)] },
      Up: { frames: [f(16, 0.2), f(16, 0.2), f(17, 0.2), f(18, 0.2), f(17, 0.2)] },
      Right: { frames: [f(31, 0.2), f(31, 0.2), f(32, 0.2), f(33, 0.2), f(32, 0.2)] },
      Left: { frames: [f(31, 0.2), f(31, 0.2), f(32, 0.2), f(33, 0.2), f(32, 0.2)] },
    },
    Walking: {
      Down: { frames: [f(5, 0.2), f(6, 0.2), f(7, 0.2), f(8, 0.2), f(9, 0.2), f(10, 0.2)] },
      Up: { frames: [f(20, 0.2), f(21, 0.2), f(22, 0.2), f(23, 0.2), f(24, 0.2), f(25, 0.2)] },
      Right: { frames: [f(35, 0.2), f(36, 0.2), f(37, 0.2), f(38, 0.2), f(39, 0.2), f(40, 0.2)] },
      Left: { frames: [f(35, 0.2), f(36, 0.2), f(37, 0.2), f(38, 0.2), f(39, 0.2), f(40, 0.2)] },
    },
    'Jumping-Start': {
      Down: one(13),
      Up: one(13),
      Right: one(13),
      Left: one(13),
    },
    'Jumping-Up': {
      Down: one(11),
      Up: one(11),
      Right: one(26),
      Left: one(41),
    },
    'Jumping-Down': {
      Down: one(12),
      Up: one(12),
      Right: one(42),
      Left: one(42),
    },
    Plowing: {
      Down: { frames: [f(46, 0.125), f(47, 0.125), f(48, 0.125), f(49, 0.125)] },
      Up: { frames: [f(61, 0.125), f(62, 0.125), f(63, 0.125), f(64, 0.125)] },
      Right: { frames: [f(76, 0.1), f(77, 0.1), f(78, 0.1), f(79, 0.1)] },
      Left: { frames: [f(76, 0.125), f(77, 0.125), f(78, 0.125), f(79, 0.125)] },
    },
    Sowing: {
      Down: { frames: [f(50, 0.125), f(51, 0.125), f(52, 0.125)] },
      Up: { frames: [f(65, 0.125), f(66, 0.125), f(67, 0.125)] },
      Right: { frames: [f(80, 0.125), f(81, 0.125), f(82, 0.125)] },
      Left: { frames: [f(80, 0.125), f(81, 0.125), f(82, 0.125)] },
    },
    Watering: {
      Down: { frames: [f(91, 0.125), f(92, 0.125), f(93, 0.125), f(94, 0.125)] },
      Up: { frames: [f(106, 0.125), f(107, 0.125), f(108, 0.125), f(109, 0.125)] },
      Right: { frames: [f(121, 0.125), f(122, 0.125), f(123, 0.125), f(124, 0.125)] },
      Left: { frames: [f(121, 0.125), f(122, 0.125), f(123, 0.125), f(124, 0.125)] },
    },
    PickUp: {
      Down: { frames: [f(95, 0.125), f(96, 0.125), f(98, 1)] },
      Up: { frames: [f(110, 0.125), f(111, 0.125), f(112, 1)] },
      Right: { frames: [f(125, 0.125), f(126, 0.125), f(127, 1)] },
      Left: { frames: [f(125, 0.125), f(126, 0.125), f(127, 1)] },
    },
  },
};

export default spriteMap;
