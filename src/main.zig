const std = @import("std");
const stdout = std.io.getStdOut().writer();

fn writeAllQuoted(writer: anytype, string: []const u8) !void {
    try writer.writeByte('"');
    try writer.writeAll(string);
    try writer.writeByte('"');
}

const Variant = union(enum) {
    boolean: bool,
    int: i32,
    uint: u32,
    double: f64,
    string: []const u8,

    fn serialize(self: Variant, writer: anytype) !void {
        try writer.print("Variant{{ .{s} = ", .{@tagName(self)});
        switch (self) {
            .boolean => |value| try writer.writeAll(if (value) "true" else "false"),
            inline .int, .uint, .double => |value| try writer.print("{d}", .{value}),
            .string => |value| try writeAllQuoted(writer, value),
        }
        try writer.writeAll(" }");
    }
};

const Setting = struct {
    []const u8, // Name
    []const u8, // Description
    Variant, // Default value
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
            try stdout.print("    .{{ \"{s}\", \"{s}\", ", .{
                setting[0],
                setting[1],
            });
            try setting[2].serialize(stdout);
            try stdout.writeAll(" },\n");
        }
        try stdout.writeAll("};\n");
    }
};

pub fn main() !void {
    const settings = [_]Setting{
        .{ "Bool_true", "True value", Variant{ .boolean = true } },
        .{ "Bool_false", "False value", Variant{ .boolean = false } },
        .{ "I32_12", "12 signed 32 bits", Variant{ .int = 123 } },
        .{ "I32__23", "-23 signed 32 bits", Variant{ .int = -123 } },
        .{ "U32_0", "0 unsigned 32 bits", Variant{ .uint = 0 } },
        .{ "U32_34", "34 unsigned 32 bits", Variant{ .uint = 34 } },
        .{ "Double_56", "5.6 double", Variant{ .double = 5.6 } },
        .{ "Double__78", "-7.8 double", Variant{ .double = -7.8 } },
        .{ "Empty", "Empty string", Variant{ .string = "" } },
        .{ "String", "Generic string value", Variant{ .string = "String" } },
    };
    const schema = Schema.factory("testfile", &settings);
    try schema.dump();
}
