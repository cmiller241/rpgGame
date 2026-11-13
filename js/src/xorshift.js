// xorshift.js
//
// A tiny 16-bit pseudorandom number generator (xorshift). Given the
// previous value it returns the next one, cycling through every number
// 1..65535 exactly once before repeating. main.js uses it to pick which
// map cells get a chance to grow crops each tick.

export default function xorshift16(x) {
  x = x | (x === 0 ? 1 : 0);   // 0 would get stuck at 0, so treat it as 1
  x = x ^ ((x & 0x07ff) << 5);
  x = x ^ (x >>> 7);
  x = x ^ ((x & 0x0003) << 14);
  return x & 0xffff;           // keep it 16-bit
}
