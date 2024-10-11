const std = @import("std");
const stdout = std.io.getStdOut().writer();
const testing = std.testing;

const Variant = union(enum) {
    boolean: bool,
    int: i32,
    uint: u32,
    float: f64,
    string: []const u8,

    fn factory(comptime T: type, value: anytype) Variant {
        return switch (T) {
            bool => Variant{ .boolean = value },
            i8, i16, i32 => Variant{ .int = value },
            u8, u16, u32 => Variant{ .uint = value },
            f16, f32, f64 => Variant{ .float = value },
            else => Variant{ .string = value },
        };
    }
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

    try writeValue(writer, Variant{ .float = -2.400 });
    try testing.expectEqualStrings(buffer.items, "Variant{ .float = -2.4 }");
    buffer.clearRetainingCapacity();

    try writeValue(writer, Variant{ .string = "string" });
    try testing.expectEqualStrings(buffer.items, "Variant{ .string = \"string\" }");
    buffer.clearRetainingCapacity();
}

const Field = struct {
    name: []const u8,
    description: []const u8,
    default: Variant,
};

const Schema = struct {
    filename: []const u8,
    fields: []const Field,

    fn factory(filename: []const u8, settings: anytype) Schema {
        const fields = comptime init: {
            var rows: [settings.len]Field = undefined;
            for (&rows, settings) |*row, setting| {
                row.* = .{ .name = setting[0], .description = setting[1], .default = Variant.factory(setting[2], setting[3]) };
            }
            break :init rows;
        };
        return Schema{
            .filename = filename,
            .fields = &fields,
        };
    }

    fn dump(self: Schema, writer: anytype) !void {
        try writer.writeAll("const settings = .{\n");
        for (self.fields) |field| {
            try writer.writeAll("    .{ ");
            try writeValue(writer, field.name);
            try writer.writeAll(", ");
            try writeValue(writer, field.description);
            try writer.writeAll(", ");
            try writeValue(writer, field.default);
            try writer.writeAll(" },\n");
        }
        try writer.writeAll("};\n");
    }
};

pub fn main() !void {
    const settings = .{
        .{ "Bool_true", "True value", bool, true },
        .{ "Bool_false", "False value", bool, false },
        .{ "I32_12", "12 signed 32 bits", i16, 123 },
        .{ "I32__23", "-23 signed 32 bits", i32, -123 },
        .{ "U32_0", "0 unsigned 32 bits", u16, 0 },
        .{ "U32_34", "34 unsigned 32 bits", u32, 34 },
        .{ "Double_56", "5.6 float", f32, 5.6 },
        .{ "Double__78", "-7.8 float", f64, -7.8 },
        .{ "Empty", "Empty string", [10]u8, "" },
        .{ "String", "Generic string value", [100]u8, "String" },
    };
    const schema = Schema.factory("testfile", settings);
    try schema.dump(stdout);
}
