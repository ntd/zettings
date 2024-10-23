const std = @import("std");
const c = @cImport({
    @cInclude("zigc.h");
});

pub fn main() !void {
    const pad24 = std.mem.zeroes(c.Pad24);
    const pad16 = std.mem.zeroes(c.Pad16);

    const expected: c_int = 1234;
    const actual = c.cFunction(pad24, pad24, pad24, pad24, pad24, pad16, expected);
    // Expected: 1234, actual 0
    std.debug.print("Expected: {d}, actual {d}\n", .{ expected, actual });
}
