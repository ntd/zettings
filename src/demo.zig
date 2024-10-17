const std = @import("std");
const eql = std.mem.eql;
const zettings = @import("Zettings.zig");

fn help(cmd: []const u8, writer: anytype) !void {
    try writer.print("Usage: {s} [OPTION]... FILE\n", .{cmd});
    try writer.writeAll(
        \\Zettings demo program.
        \\
        \\Available options:
        \\  -r              Create or reset the schema file
        \\  -t              Toggle boolean settings
        \\  -i              Increment numeric settings
        \\  -d              Dump the actual schema contents
        \\  -h, --help      Display this help and exit
        \\
        \\FILE is required and must be writable.
        \\
    );
}

fn absolutePath(allocator: std.mem.Allocator, src: []const u8) ![]u8 {
    const path = std.fs.path;
    if (path.isAbsolute(src)) {
        return path.resolve(allocator, &[_][]const u8{src});
    } else {
        // `src` is relative and I need to prepend CWD but:
        // - I don't know how to resolve `std.fs.cwd` because
        //   `std.os.getFdPath` has the following comment:
        //       "Calling this function is usually a bug."
        // - `std.posix.realpath` & friends require a pre-existing file
        //   and they are planned to be removed in the near future:
        //     https://github.com/ziglang/zig/issues/19353
        // At the end, `getCwdAlloc` seems to be the sanest choice.
        const cwd = try std.process.getCwdAlloc(allocator);
        defer allocator.free(cwd);
        return path.resolve(allocator, &[_][]const u8{ cwd, src });
    }
}

const Actions = struct {
    reset: bool = false,
    toggle: bool = false,
    increment: bool = false,
    dump: bool = false,

    pub fn todo(self: *Actions, comptime action: []const u8) bool {
        const result = @field(self, action);
        @field(self, action) = false;
        return result;
    }

    pub fn pending(self: Actions) bool {
        return self.reset or self.toggle or self.increment or self.dump;
    }
};

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();
    var actions: Actions = .{};
    var no_more_options = false;
    var filearg: ?[]const u8 = null;

    var args = std.process.args();
    const cmd = args.next().?;

    while (args.next()) |arg| {
        if (no_more_options or arg[0] != '-') {
            if (filearg) |_| {
                try stderr.writeAll("Too many schema files!\n");
                try help(cmd, stdout);
                return error.TooManyFiles;
            } else {
                filearg = arg;
            }
        } else if (eql(u8, arg, "-h") or eql(u8, arg, "--help")) {
            try help(cmd, stdout);
            return;
        } else if (eql(u8, arg, "-r")) {
            actions.reset = true;
        } else if (eql(u8, arg, "-t")) {
            actions.toggle = true;
        } else if (eql(u8, arg, "-i")) {
            actions.increment = true;
        } else if (eql(u8, arg, "-d")) {
            actions.dump = true;
        } else if (eql(u8, arg, "--")) {
            no_more_options = true;
        } else {
            try stderr.print("Invalid argument: '{s}'\n", .{arg});
            try help(cmd, stdout);
            return error.InvalidArgument;
        }
    }

    if (filearg == null) {
        try stderr.writeAll("Schema file not specified!\n");
        try help(cmd, stdout);
        return error.FileNotSpecified;
    }

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Ensure `filepath` is the absolute path to `filearg`
    const filepath = try absolutePath(allocator, filearg.?);
    defer allocator.free(filepath);

    const settings = .{
        .{ "BOOL", "A boolean value", bool, false },
        .{ "I16", "Signed integer (16 bits)", i16, -1 },
        .{ "I32", "Signed integer (32 bits)", i32, -2 },
        .{ "U8", "A byte", u8, 253 },
        .{ "U32", "Unsigned integer (32 bits)", u32, 34 },
        .{ "F64", "Floating point (64 bits)", f64, -7.8 },
        .{ "EMPTY", "Empty string", [10:0]u8, "" },
        .{ "STRING", "Valorized string", [100:0]u8, "String" },
    };
    var schema = zettings.Schema(settings).init(filepath);
    defer schema.deinit();

    if (actions.todo("reset")) {
        try schema.reset();
    }

    if (actions.pending()) {
        try schema.mmap();

        if (actions.todo("toggle")) {
            schema.image.?.BOOL = !schema.image.?.BOOL;
        }
        if (actions.todo("increment")) {
            schema.image.?.I16 += 1;
            schema.image.?.I32 += 1;
            schema.image.?.U8 += 1;
            schema.image.?.U32 += 1;
            schema.image.?.F64 += 1;
        }
        if (actions.todo("dump")) {
            try schema.dump(stdout);
        }
    }
}
