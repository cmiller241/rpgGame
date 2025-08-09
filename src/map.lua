local bit = require('bit')

function xorshift16(x)
    x = bit.bor(x, x == 0 and 1 or 0) -- if x == 0, set x = 1
    x = bit.bxor(x, bit.lshift(bit.band(x, 0x07ff), 5))
    x = bit.bxor(x, bit.rshift(x, 7))
    x = bit.bxor(x, bit.lshift(bit.band(x, 0x0003), 14))
    return bit.band(x, 0xffff) -- Ensure 16-bit output
end