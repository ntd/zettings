const std = @import("std");
const stdout = std.io.getStdOut().writer();

const Variant = union(enum) {
    bool: bool,
    int: i32,
    uint: u32,
    double: f64,
    string: []const u8,

    fn factory(comptime T: type, value: T) Variant {
        const variant: Variant = switch (T) {
            bool => .{ .bool = value },
            i32 => .{ .int = value },
            u32 => .{ .uint = value },
            f64 => .{ .double = value },
            []const u8 => .{ .string = value },
            else => unreachable(),
        };
        return variant;
    }

    fn zig_type(self: Variant) []const u8 {
        return switch (self) {
            Variant.bool => "bool",
            Variant.int => "i32",
            Variant.uint => "u32",
            Variant.double => "f64",
            Variant.string => "[]const u8",
        };
    }

    fn dump(self: Variant) !void {
        switch (self) {
            Variant.bool => |value| try stdout.print("{s}", .{if (value) "true" else "false"}),
            Variant.int => |value| try stdout.print("{d}", .{value}),
            Variant.uint => |value| try stdout.print("{d}", .{value}),
            Variant.double => |value| try stdout.print("{d}", .{value}),
            Variant.string => |value| try stdout.print("\"{s}\"", .{value}),
        }
    }
};

const Setting = struct {
    name: []const u8,
    description: []const u8,
    default: Variant,

    fn factory(name: []const u8, description: []const u8, comptime T: type, default: T) Setting {
        const setting: Setting = .{
            .name = name,
            .description = description,
            .default = Variant.factory(T, default),
        };
        return setting;
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
        const schema: Schema = .{
            .filename = filename,
            .settings = settings,
        };
        return schema;
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
