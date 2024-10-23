const std = @import("std");
const c = @cImport({
    @cInclude("zigc.h");
});

pub fn main() !void {
    const pad24 = std.mem.zeroes(c.Pad24);
    const pad16 = std.mem.zeroes(c.Pad16);
    const sentinel: *anyopaque = @ptrFromInt(0xC0FEE000);
    c.cFunction(pad24, pad24, pad24, pad24, pad24, pad16, sentinel);
}
