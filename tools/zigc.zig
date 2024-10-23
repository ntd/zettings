const std = @import("std");
const c = @cImport({
    @cInclude("zigc.h");
});

pub fn main() !void {
    const pad24 = std.mem.zeroes(c.Pad24);
    const pad16 = std.mem.zeroes(c.Pad16);
    const expected = 0xC0FEE000;
    const sentinel: *anyopaque = @ptrFromInt(expected);

    const actual = c.cFunction(pad24, pad24, pad24, pad24, pad24, pad16, sentinel);
    // Expected: 0xC0FEE000, actual 0x0
    std.debug.print("Expected: 0x{X}, actual 0x{X}\n", .{ expected, actual });
}
