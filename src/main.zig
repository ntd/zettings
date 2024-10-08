const std = @import("std");
const stdout = std.io.getStdOut().writer();

const Variant = union(enum) {
    boolean: bool,
    int: i32,
    uint: u32,
    double: f64,
    string: []const u8,

    fn factory(comptime T: type, value: T) Variant {
        return switch (T) {
            bool => .{ .boolean = value },
            i32 => .{ .int = value },
            u32 => .{ .uint = value },
            f64 => .{ .double = value },
            []const u8 => .{ .string = value },
            else => unreachable(),
        };
    }

    fn zig_type(self: Variant) []const u8 {
        return switch (self) {
            .boolean => "bool",
            .int => "i32",
            .uint => "u32",
            .double => "f64",
            .string => "[]const u8",
        };
    }

    fn dump(self: Variant) !void {
        switch (self) {
            .boolean => |value| try stdout.writeAll(if (value) "true" else "false"),
            inline .int, .uint, .double => |value| try stdout.print("{d}", .{value}),
            .string => |value| try stdout.print("\"{s}\"", .{value}),
        }
    }
};

const Setting = struct {
    name: []const u8,
    description: []const u8,
    default: Variant,

    fn factory(name: []const u8, description: []const u8, comptime T: type, default: T) Setting {
        return .{
            .name = name,
            .description = description,
            .default = Variant.factory(T, default),
        };
    }

    fn dump(self: Setting) !void {
        try stdout.print("S(\"{s}\", \"{s}\", {s}, ", .{
            self.name,
            self.description,
            self.default.zig_type(),
        });
        try self.default.dump();
        try stdout.writeAll("),\n");
    }
};

const Schema = struct {
    filename: []const u8,
    settings: []const Setting,

    fn factory(filename: []const u8, settings: []const Setting) Schema {
        return .{
            .filename = filename,
            .settings = settings,
        };
    }

    fn dump(self: Schema) !void {
        try stdout.writeAll("const settings = [_]Settings{\n");
        for (self.settings) |setting| {
            try stdout.writeAll("    ");
            try setting.dump();
        }
        try stdout.writeAll("};\n");
    }
};

pub fn main() !void {
    // Shorthand for easier settings definition
    const S = Setting.factory;
    const settings = [_]Setting{
        S("Bool_true", "True value", bool, true),
        S("Bool_false", "False value", bool, false),
        S("I32_12", "12 signed 32 bits", i32, 123),
        S("I32__23", "-23 signed 32 bits", i32, -123),
        S("U32_0", "0 unsigned 32 bits", u32, 0),
        S("U32_34", "34 unsigned 32 bits", u32, 34),
        S("Double_56", "5.6 double", f64, 5.6),
        S("Double__78", "-7.8 double", f64, -7.8),
        S("Empty", "Empty string", []const u8, ""),
        S("String", "Generic string value", []const u8, "String"),
    };
    const schema = Schema.factory("testfile", &settings);
    try schema.dump();
}
