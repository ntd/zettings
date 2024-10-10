const std = @import("std");
const stdout = std.io.getStdOut().writer();
const testing = std.testing;

const Variant = union(enum) {
    boolean: bool,
    int: i32,
    uint: u32,
    double: f64,
    string: []const u8,
};

fn writeValue(writer: anytype, value: anytype) !void {
    switch (@typeInfo(@TypeOf(value))) {
        .Bool => try writer.writeAll(if (value) "true" else "false"),
        .Int, .Float, .ComptimeInt, .ComptimeFloat => try writer.print("{d}", .{value}),
        .Union => { // The value is supposedly a `Variant`
            try writer.writeAll("Variant{ .");
            try writer.writeAll(@tagName(value));
            try writer.writeAll(" = ");
            switch (value) {
                inline else => |payload| try writeValue(writer, payload),
            }
            try writer.writeAll(" }");
        },
        else => {
            try writer.writeByte('"');
            try writer.writeAll(value);
            try writer.writeByte('"');
        },
    }
}

test "writeValue" {
    var buffer = std.ArrayList(u8).init(testing.allocator);
    defer buffer.deinit();

    const writer = buffer.writer();

    try writeValue(writer, "string");
    try testing.expectEqualStrings(buffer.items, "\"string\"");
    buffer.clearRetainingCapacity();

    try writeValue(writer, "");
    try testing.expectEqualStrings(buffer.items, "\"\"");
    buffer.clearRetainingCapacity();

    try writeValue(writer, false);
    try testing.expectEqualStrings(buffer.items, "false");
    buffer.clearRetainingCapacity();

    try writeValue(writer, true);
    try testing.expectEqualStrings(buffer.items, "true");
    buffer.clearRetainingCapacity();

    try writeValue(writer, 1.234);
    try testing.expectEqualStrings(buffer.items, "1.234");
    buffer.clearRetainingCapacity();

    try writeValue(writer, -42);
    try testing.expectEqualStrings(buffer.items, "-42");
    buffer.clearRetainingCapacity();

    try writeValue(writer, Variant{ .boolean = true });
    try testing.expectEqualStrings(buffer.items, "Variant{ .boolean = true }");
    buffer.clearRetainingCapacity();

    try writeValue(writer, Variant{ .boolean = false });
    try testing.expectEqualStrings(buffer.items, "Variant{ .boolean = false }");
    buffer.clearRetainingCapacity();

    try writeValue(writer, Variant{ .int = 0 });
    try testing.expectEqualStrings(buffer.items, "Variant{ .int = 0 }");
    buffer.clearRetainingCapacity();

    try writeValue(writer, Variant{ .int = -123 });
    try testing.expectEqualStrings(buffer.items, "Variant{ .int = -123 }");
    buffer.clearRetainingCapacity();

    try writeValue(writer, Variant{ .uint = 84200 });
    try testing.expectEqualStrings(buffer.items, "Variant{ .uint = 84200 }");
    buffer.clearRetainingCapacity();

    try writeValue(writer, Variant{ .double = -2.400 });
    try testing.expectEqualStrings(buffer.items, "Variant{ .double = -2.4 }");
    buffer.clearRetainingCapacity();

    try writeValue(writer, Variant{ .string = "string" });
    try testing.expectEqualStrings(buffer.items, "Variant{ .string = \"string\" }");
    buffer.clearRetainingCapacity();
}

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

    fn dump(self: Schema, writer: anytype) !void {
        try writer.writeAll("const settings = .{\n");
        for (self.settings) |setting| {
            try writer.writeAll("    .{ ");
            try writeValue(writer, setting[0]);
            try writer.writeAll(", ");
            try writeValue(writer, setting[1]);
            try writer.writeAll(", ");
            try writeValue(writer, setting[2]);
            try writer.writeAll(" },\n");
        }
        try writer.writeAll("};\n");
    }
};

pub fn main() !void {
    const settings = .{
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
    try schema.dump(stdout);
}
