-- xorshift.lua
--
-- A tiny 16-bit pseudorandom number generator (xorshift). Given the
-- previous value it returns the next one, cycling through every number
-- 1..65535 exactly once before repeating. main.lua uses it to pick which
-- map cells get a chance to grow crops each tick.

local bit = require("bit")

local function xorshift16(x)
    x = bit.bor(x, x == 0 and 1 or 0) -- 0 would get stuck at 0, so treat it as 1
    x = bit.bxor(x, bit.lshift(bit.band(x, 0x07ff), 5))
    x = bit.bxor(x, bit.rshift(x, 7))
    x = bit.bxor(x, bit.lshift(bit.band(x, 0x0003), 14))
    return bit.band(x, 0xffff) -- keep it 16-bit
end

return xorshift16
