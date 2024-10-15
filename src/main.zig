const std = @import("std");
const expect = std.testing.expect;
const expectEqualStrings = std.testing.expectEqualStrings;
const posix = std.posix;

const Member = struct {
    // 0-terminated because @Type needs that
    name: [:0]const u8,
    type: type,
};

/// Not sure this is the proper way to do it: I need to copy a string
/// to an [_]u8 array that can be (and usually it is) smaller than
/// the string itsself
fn strcpy(dst: anytype, src: []const u8) void {
    @memcpy(dst[0..src.len], src);
    dst[src.len] = 0;
}

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

pub const SchemaError = error{
    FileAlreadyMmapped,
};

fn Schema(comptime settings: anytype) type {
    var members: [settings.len]Member = undefined;
    for (settings, 0..) |setting, i| {
        members[i] = .{ .name = setting[0], .type = setting[2] };
    }
    const ComputedImage = comptime buildStruct(&members);
    return struct {
        const Self = @This();
        pub const Image = ComputedImage;

        filepath: []const u8,
        defaults: Image,
        image: ?*align(std.mem.page_size) Image = null,

        pub fn init(filepath: []const u8) Self {
            var defaults: Image = undefined;
            inline for (settings) |setting| {
                const name = setting[0];
                const T = setting[2];
                const value = setting[3];
                switch (@typeInfo(T)) {
                    .Bool, .Int, .Float => @field(defaults, name) = value,
                    else => {
                        // This is probably a string type, so assuming
                        // the default value is a slice here
                        if (@sizeOf(T) < value.len) {
                            @compileError("Default value '" ++ value ++
                                "' too big for field '" ++ name ++ "'");
                        }
                        strcpy(&@field(defaults, name), value);
                        //@memcpy(@field(defaults, name)[0..value.len], value);
                        //@field(defaults, name)[value.len] = 0;
                    },
                }
            }
            return .{
                .filepath = filepath,
                .defaults = defaults,
            };
        }

        pub fn deinit(self: Self) void {
            if (self.image) |image| {
                posix.munmap(std.mem.asBytes(image));
            }
        }

        /// Create or reset the file to the default image values.
        pub fn reset(self: Self) !void {
            if (self.image) |_| {
                return SchemaError.FileAlreadyMmapped;
            }
            const file = try std.fs.createFileAbsolute(self.filepath, .{ .truncate = true, .exclusive = false, .mode = 0o660 });
            try file.writeAll(std.mem.asBytes(&self.defaults));
            file.close();
        }

        pub fn mmap(self: *Self) !void {
            const file = try std.fs.openFileAbsolute(self.filepath, .{ .mode = .read_write });
            defer file.close();
            const image = try posix.mmap(null, @sizeOf(Image), posix.PROT.READ | posix.PROT.WRITE, .{ .TYPE = .SHARED }, file.handle, 0);
            self.image = @ptrCast(image.ptr);
        }

        pub fn dump(self: Self, writer: anytype) !void {
            const image = self.image orelse &self.defaults;
            inline for (settings) |setting| {
                const name = setting[0];
                const description = setting[1];
                const T = setting[2];
                try writer.writeAll(".{ \"" ++ name ++ "\", \"" ++ description ++ "\", " ++ @typeName(T) ++ ", ");
                const value = @field(image, name);
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

test "Schema.dump" {
    var buffer = std.ArrayList(u8).init(std.testing.allocator);
    defer buffer.deinit();
    const writer = buffer.writer();

    { // Empty schema
        const schema = Schema(.{}).init("dummy");
        defer schema.deinit();
        try schema.dump(writer);
        try expectEqualStrings("", buffer.items);
        buffer.clearRetainingCapacity();
    }
    { // Schema with a single boolean setting
        const schema = Schema(.{.{ "TRUE", "Boolean value", bool, true }}).init("dummy");
        defer schema.deinit();
        try schema.dump(writer);
        try expectEqualStrings(".{ \"TRUE\", \"Boolean value\", bool, true },\n", buffer.items);
        try expectEqualStrings(
            \\.{ "TRUE", "Boolean value", bool, true },
            \\
        , buffer.items);
        buffer.clearRetainingCapacity();
    }
    { // Schema with various numeric settings
        const settings = .{
            .{ "I16", "An i16", i16, -123 },
            .{ "U32", "An u32", u32, 56789 },
            .{ "f64", "An f64", f64, -90.1234 },
        };
        const schema = Schema(settings).init("dummy");
        defer schema.deinit();
        try schema.dump(writer);
        try expectEqualStrings(
            \\.{ "I16", "An i16", i16, -123 },
            \\.{ "U32", "An u32", u32, 56789 },
            \\.{ "f64", "An f64", f64, -90.1234 },
            \\
        , buffer.items);
        buffer.clearRetainingCapacity();
    }
    { // Various settings
        const settings = .{
            .{ "FALSE", "False boolean value", bool, false },
            .{ "I32", "Signed integer (32 bits)", i32, -1234567 },
            .{ "F32", "Floating point (32 bits)", f32, 89.01234 },
            .{ "EMPTY", "Empty string", [10:0]u8, "" },
            .{ "STRING", "Valorized string", [100:0]u8, "String" },
            .{ "NONUL", "String without terminator", [100]u8, "Something" },
        };
        const schema = Schema(settings).init("dummy");
        defer schema.deinit();
        try schema.dump(writer);
        try expectEqualStrings(
            \\.{ "FALSE", "False boolean value", bool, false },
            \\.{ "I32", "Signed integer (32 bits)", i32, -1234567 },
            \\.{ "F32", "Floating point (32 bits)", f32, 89.01234 },
            \\.{ "EMPTY", "Empty string", [10:0]u8, "" },
            \\.{ "STRING", "Valorized string", [100:0]u8, "String" },
            \\.{ "NONUL", "String without terminator", [100]u8, "Something" },
            \\
        , buffer.items);
        buffer.clearRetainingCapacity();
    }
}

test "Schema.mmap" {
    // This test requires writing permission to this file
    const filepath = "/tmp/test.schema";

    var buffer = std.ArrayList(u8).init(std.testing.allocator);
    defer buffer.deinit();
    const writer = buffer.writer();

    const settings = .{
        .{ "B", "Boolean", bool, true },
        .{ "I", "Integer", i32, -1 },
        .{ "F", "Floating", f64, -2 },
        .{ "S", "String", [50:0]u8, "-3" },
    };
    var schema = Schema(settings).init(filepath);

    // Creates the schema file/resets to default values
    try schema.reset();

    // Check the default values are enforced
    try schema.dump(writer);
    try expectEqualStrings(
        \\.{ "B", "Boolean", bool, true },
        \\.{ "I", "Integer", i32, -1 },
        \\.{ "F", "Floating", f64, -2 },
        \\.{ "S", "String", [50:0]u8, "-3" },
        \\
    , buffer.items);
    buffer.clearRetainingCapacity();

    // Before mmapping, `image` should be null
    try expect(schema.image == null);

    // After mmapping, `image` should be valorized
    try schema.mmap();
    try expect(schema.image != null);

    // After the schema file has been mapped, `reset` must fail
    try std.testing.expectError(SchemaError.FileAlreadyMmapped, schema.reset());

    // Change setting values
    schema.image.?.B = false;
    schema.image.?.I = 1;
    schema.image.?.F = 2;
    strcpy(&schema.image.?.S, "whatever");

    // Check the dump is up to date
    try schema.dump(writer);
    try expectEqualStrings(
        \\.{ "B", "Boolean", bool, false },
        \\.{ "I", "Integer", i32, 1 },
        \\.{ "F", "Floating", f64, 2 },
        \\.{ "S", "String", [50:0]u8, "whatever" },
        \\
    , buffer.items);
    buffer.clearRetainingCapacity();

    // Close and reopen to see if setting values are retained
    schema.deinit();
    schema = Schema(settings).init(filepath);
    try schema.mmap();

    try schema.dump(writer);
    try expectEqualStrings(
        \\.{ "B", "Boolean", bool, false },
        \\.{ "I", "Integer", i32, 1 },
        \\.{ "F", "Floating", f64, 2 },
        \\.{ "S", "String", [50:0]u8, "whatever" },
        \\
    , buffer.items);
    buffer.clearRetainingCapacity();

    // Test if `reset` restores default values
    schema.deinit();
    schema = Schema(settings).init(filepath);
    try schema.reset();
    try schema.dump(writer);
    try expectEqualStrings(
        \\.{ "B", "Boolean", bool, true },
        \\.{ "I", "Integer", i32, -1 },
        \\.{ "F", "Floating", f64, -2 },
        \\.{ "S", "String", [50:0]u8, "-3" },
        \\
    , buffer.items);
    buffer.clearRetainingCapacity();

    try posix.unlink(filepath);
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
    var schema2 = Schema(.{.{ "TRUE", "Boolean value", bool, true }}).init("/tmp/testfile2");
    try schema2.dump(stdout);

    var schema = Schema(settings).init("/tmp/testfile");
    defer schema.deinit();

    try schema.reset();
    try schema.mmap();
    try schema.dump(stdout);

    //// Try changing some fields and see if dump works as expected
    try stdout.writeByte('\n');
    schema.image.?.TRUE = false;
    schema.image.?.FALSE = true;
    schema.image.?.STRING[0] = 0;
    try schema.dump(stdout);
}
