const std = @import("std");

const Member = struct {
    // 0-terminated because @Type needs that
    name: [:0]const u8,
    type: type,
};

/// Helper function to create a struct from a set of members
fn buildStruct(members: []const Member) type {
    var fields: [members.len]std.builtin.Type.StructField = undefined;
    for (members, 0..) |member, i| {
        const T = member.type;
        fields[i] = .{
            .name = member.name,
            .type = T,
            .default_value = null,
            .is_comptime = false,
            .alignment = if (@sizeOf(T) > 0) @alignOf(T) else 0,
        };
    }
    return @Type(.{ .Struct = .{
        .is_tuple = false,
        .layout = .auto,
        .fields = &fields,
        .decls = &.{},
    } });
}

test "buildStruct" {
    const expect = std.testing.expect;
    const expectEqualStrings = std.testing.expectEqualStrings;

    const members = [_]Member{
        .{ .name = "field1", .type = u8 },
        .{ .name = "field2", .type = f64 },
        .{ .name = "field3", .type = []const u8 },
        .{ .name = "field4", .type = [10:0]u8 },
    };

    const test_struct = buildStruct(&members);

    const fields = std.meta.fields(test_struct);
    try expect(fields.len == 4);
    try expectEqualStrings("field1", fields[0].name);
    try expect(fields[0].type == u8);
    try expectEqualStrings("field2", fields[1].name);
    try expect(fields[1].type == f64);
    try expectEqualStrings("field3", fields[2].name);
    try expect(fields[2].type == []const u8);
    try expectEqualStrings("field4", fields[3].name);
    try expect(fields[3].type == [10:0]u8);
}

fn Schema(comptime settings: anytype) type {
    var members: [settings.len]Member = undefined;
    for (settings, 0..) |setting, i| {
        members[i] = .{ .name = setting[0], .type = setting[2] };
    }
    const ComputedImage = comptime buildStruct(&members);
    return struct {
        const Self = @This();
        pub const Image = ComputedImage;

        filename: []const u8,
        image: Image,

        pub fn init(filename: []const u8) Self {
            var image: Image = undefined;
            inline for (settings) |setting| {
                const name = setting[0];
                const T = setting[2];
                const value = setting[3];
                switch (@typeInfo(T)) {
                    .Bool, .Int, .Float => @field(image, name) = value,
                    else => {
                        // This is probably a string type, so assuming
                        // the default value is a slice here
                        if (@sizeOf(T) < value.len) {
                            unreachable;
                        }
                        @memcpy(@field(image, name)[0..value.len], value);
                        @field(image, name)[value.len] = 0;
                    },
                }
            }
            return .{
                .filename = filename,
                .image = image,
            };
        }

        pub fn dump(self: Self, writer: anytype) !void {
            inline for (settings) |setting| {
                const name = setting[0];
                const description = setting[1];
                const T = setting[2];
                try writer.writeAll(".{ \"" ++ name ++ "\", \"" ++ description ++ "\", ");
                const value = @field(self.image, name);
                switch (@typeInfo(T)) {
                    .Bool => try writer.writeAll(if (value) "true" else "false"),
                    .Int, .Float => try writer.print("{d}", .{value}),
                    else => {
                        const text = std.mem.sliceTo(&value, 0);
                        try writer.print("\"{s}\"", .{text});
                    },
                }
                try writer.writeAll(" },\n");
            }
        }
    };
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    const settings = .{
        .{ "TRUE", "True boolean value", bool, true },
        .{ "FALSE", "False boolean value", bool, false },
        .{ "I16", "Signed integer (16 bits)", i16, 123 },
        .{ "I32", "Signed integer (32 bits)", i32, -123 },
        .{ "U16", "Unsigned integer (16 bits)", u16, 0 },
        .{ "U32", "Unsigned integer (32 bits)", u32, 34 },
        .{ "F32", "Floating point (32 bits)", f32, 5.6 },
        .{ "F64", "Floating point (64 bits)", f64, -7.8 },
        .{ "EMPTY", "Empty string", [10:0]u8, "" },
        .{ "STRING", "Valorized string", [100:0]u8, "String" },
    };
    var schema = Schema(settings).init("testfile");
    try schema.dump(stdout);

    // Try changing some fields and see if dump works as expected
    try stdout.writeByte('\n');
    schema.image.TRUE = false;
    schema.image.FALSE = true;
    schema.image.STRING[0] = 0;
    try schema.dump(stdout);
}
