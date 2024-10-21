const std = @import("std");
const expect = std.testing.expect;
const expectEqualSlices = std.testing.expectEqualSlices;

// TODO: Zig lacks proper support for bitfields. See ziglang/zig#1499:
//     https://github.com/ziglang/zig/issues/1499
//
// Above all, the C-translator maps any struct with bitfield members to
// an opaque object *without* defined size, making impossible to e.g.
// declare arrays of such types.
//
// Many fundamental open62541 types, such as `UA_DataType` and
// `UA_DataValue`, use bitfields, so the inclusion of some header
// triggers errors similar to the following one:
//     ...: error: opaque types have unknown size and therefore cannot be directly embedded in structs
//     value: UA_DataValue = @import("std").mem.zeroes(UA_DataValue),
//
const c = @cImport({
    @cInclude("open62541/types.h");
    // See above: @cInclude("open62541/server.h");
    // See above: @cInclude("open62541/server_config_default.h");
});

// TODO: drop the following declarations and use the C imported
// counterparts whenever Zig gains proper support for bitfields
pub const UA_Server = c.UA_Server;
pub const UA_NodeId = c.UA_NodeId;
pub const UA_StatusCode = c.UA_StatusCode;

const UA_DataTypeFlags = packed struct {
    memSize: u16,
    typeKind: u6,
    pointerFree: u1,
    overlayable: u1,
    membersSize: u8,
};

const UA_DataType = extern struct {
    typeName: ?[*:0]const u8,
    typeId: UA_NodeId,
    binaryEncodingId: UA_NodeId,
    flags: u32,
    members: ?*anyopaque,
};

extern const UA_TYPES: [c.UA_TYPES_COUNT]UA_DataType;

// XXX: workaround for accessing bitfields in Zig
fn dtFlags(dt: *UA_DataType) *UA_DataTypeFlags {
    return @ptrCast(&dt.flags);
}

// Test expected to succeed on a x86_64-pc-linux-gnu systems
test "UA_DataType" {
    try expect(@sizeOf(UA_DataType) == 72);

    var dt = std.mem.zeroes(UA_DataType);
    dt.typeName = @ptrFromInt(0x89ABCDEF);
    dtFlags(&dt).memSize = 0x1234;
    dtFlags(&dt).typeKind = 10;
    dtFlags(&dt).overlayable = 1;
    dtFlags(&dt).membersSize = 0x56;
    dt.members = @ptrFromInt(0xFEDCBA98);

    const expected: []const u8 = &.{
        0xEF, 0xCD, 0xAB, 0x89, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x34, 0x12, 0x8A, 0x56, 0x00, 0x00, 0x00, 0x00,
        0x98, 0xBA, 0xDC, 0xFE, 0x00, 0x00, 0x00, 0x00,
    };
    try expectEqualSlices(u8, expected, std.mem.asBytes(&dt));
}

const UA_DataValueFlags = packed struct {
    hasValue: u1,
    hasStatus: u1,
    hasSourceTimestamp: u1,
    hasServerTimestamp: u1,
    hasSourcePicoseconds: u1,
    hasServerPicoseconds: u1,
};

const UA_DataValue = extern struct {
    value: c.UA_Variant,
    sourceTimestamp: c.UA_DateTime,
    serverTimestamp: c.UA_DateTime,
    sourcePicoseconds: u16,
    serverPicoseconds: u16,
    status: UA_StatusCode,
    flags: u8,
};

// XXX: workaround for accessing bitfields in Zig
fn dvFlags(dv: *UA_DataValue) *UA_DataValueFlags {
    return @ptrCast(&dv.flags);
}

// Test expected to succeed on a x86_64-pc-linux-gnu systems
test "UA_DataValue" {
    try expect(@sizeOf(UA_DataValue) == 80);

    var dv = std.mem.zeroes(UA_DataValue);
    dv.sourceTimestamp = 0x123456789ABCDEF0;
    dv.serverTimestamp = 0x0102030405060708;
    dv.sourcePicoseconds = 0x1234;
    dv.serverPicoseconds = 0x5678;
    dv.status = 0x09ABCDEF;
    dvFlags(&dv).hasStatus = 1;
    dvFlags(&dv).hasServerTimestamp = 1;
    dvFlags(&dv).hasSourcePicoseconds = 1;

    const expected: []const u8 = &.{
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0xF0, 0xDE, 0xBC, 0x9A, 0x78, 0x56, 0x34, 0x12,
        0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01,
        0x34, 0x12, 0x78, 0x56, 0xEF, 0xCD, 0xAB, 0x09,
        0x1A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    };
    try expectEqualSlices(u8, expected, std.mem.asBytes(&dv));
}

pub extern fn UA_Server_new() ?*UA_Server;
pub extern fn UA_Server_delete(server: *UA_Server) UA_StatusCode;
pub extern fn UA_Server_run(server: *UA_Server, running: *bool) UA_StatusCode;

// Not exposed: use `serverConfigure()` instead
extern fn UA_Server_getConfig(server: *UA_Server) ?*c.UA_ServerConfig;
extern fn UA_ServerConfig_setMinimalCustomBuffer(config: ?*c.UA_ServerConfig, portNumber: u16, certificate: ?*const c.UA_ByteString, sendBufferSize: u32, recvBufferSize: u32) UA_StatusCode;

// TODO: provide more detailed error codes
pub const OPCUAError = error{
    UnableToCreateServer,
    BadStatusCode,
};

pub fn fallible(status: UA_StatusCode) !void {
    if (c.UA_StatusCode_isBad(status)) {
        return OPCUAError.BadStatusCode;
    }
}

pub const Configuration = struct {
    portNumber: u16 = 4840,
};

pub fn serverConfigure(server: *UA_Server, configuration: Configuration) !void {
    const opcua_config = UA_Server_getConfig(server);
    try fallible(UA_ServerConfig_setMinimalCustomBuffer(opcua_config, configuration.portNumber, null, 0, 0));
}
