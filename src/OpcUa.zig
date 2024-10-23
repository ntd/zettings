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
    @cInclude("open62541/util.h");
    // See above: @cInclude("open62541/server.h");
    // See above: @cInclude("open62541/server_config_default.h");
    @cInclude("open62541/plugin/nodestore.h"); // UA_DataSource
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
fn dtRead(dt: *const UA_DataType) *const UA_DataTypeFlags {
    return @ptrCast(&dt.flags);
}
fn dtWrite(dt: *UA_DataType) *UA_DataTypeFlags {
    return @ptrCast(&dt.flags);
}

// Test expected to succeed on a x86_64-pc-linux-gnu systems
test "UA_DataType" {
    try expect(@sizeOf(UA_DataType) == 72);

    var dt = std.mem.zeroes(UA_DataType);
    dt.typeName = @ptrFromInt(0x89ABCDEF);
    dtWrite(&dt).memSize = 0x1234;
    dtWrite(&dt).typeKind = 10;
    dtWrite(&dt).overlayable = 1;
    dtWrite(&dt).membersSize = 0x56;
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
fn dvRead(dv: *const UA_DataValue) *const UA_DataValueFlags {
    return @ptrCast(&dv.flags);
}
fn dvWrite(dv: *UA_DataValue) *UA_DataValueFlags {
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
    dvWrite(&dv).hasStatus = 1;
    dvWrite(&dv).hasServerTimestamp = 1;
    dvWrite(&dv).hasSourcePicoseconds = 1;

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

pub extern fn UA_Server_new() callconv(.C) ?*UA_Server;
pub extern fn UA_Server_delete(server: *UA_Server) callconv(.C) UA_StatusCode;
pub extern fn UA_Server_run(server: *UA_Server, running: *bool) callconv(.C) UA_StatusCode;

// Not exposed: use `serverConfigure()` instead
extern fn UA_Server_getConfig(server: *UA_Server) callconv(.C) ?*c.UA_ServerConfig;
extern fn UA_ServerConfig_setMinimalCustomBuffer(config: *c.UA_ServerConfig, portNumber: u16, certificate: ?*const c.UA_ByteString, sendBufferSize: u32, recvBufferSize: u32) callconv(.C) UA_StatusCode;

// Not exposed: use `createFolder()` instead
extern fn __UA_Server_addNode(server: *UA_Server, nodeClass: c.UA_NodeClass, requestedNewNodeId: *const UA_NodeId, parentNodeId: *const UA_NodeId, referenceTypeId: *const UA_NodeId, browseName: c.UA_QualifiedName, typeDefinition: *const UA_NodeId, attr: *const c.UA_NodeAttributes, attributeType: *const UA_DataType, nodeContext: ?*anyopaque, outNewNodeId: ?*UA_NodeId) callconv(.C) UA_StatusCode;

// Not exposed: use `bindSetting()` instead
extern fn UA_Server_addDataSourceVariableNode(server: *UA_Server, requestedNewNodeId: UA_NodeId, parentNodeId: UA_NodeId, referenceTypeId: UA_NodeId, browseName: c.UA_QualifiedName, typeDefinition: UA_NodeId, attr: c.UA_VariableAttributes, dataSource: c.UA_DataSource, nodeContext: ?*anyopaque, outNewNodeId: ?*UA_NodeId) callconv(.C) UA_StatusCode;
extern fn UA_Variant_setScalarCopy(v: *c.UA_Variant, p: *const anyopaque, type: *const UA_DataType) callconv(.C) UA_StatusCode;

// TODO: provide more detailed error codes
pub const OPCUAError = error{
    UnableToCreateServer,
    InvalidServer,
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
    const opcua_config = UA_Server_getConfig(server) orelse return OPCUAError.InvalidServer;
    try fallible(UA_ServerConfig_setMinimalCustomBuffer(opcua_config, configuration.portNumber, null, 0, 0));
}

/// Create a bare folder under Root/Objects
pub fn createFolder(server: *UA_Server, name: []const u8, namespace: u16) !UA_NodeId {
    const parentNodeId = c.UA_NODEID_NUMERIC(0, c.UA_NS0ID_OBJECTSFOLDER);
    const referenceTypeId = c.UA_NODEID_NUMERIC(0, c.UA_NS0ID_ORGANIZES);
    const browseName = c.UA_QUALIFIEDNAME(namespace, @constCast(name.ptr));
    const typeDefinition = c.UA_NODEID_NUMERIC(0, c.UA_NS0ID_BASEOBJECTTYPE);
    const attr = c.UA_ObjectAttributes_default;

    var result: UA_NodeId = undefined;
    try fallible(__UA_Server_addNode(server, c.UA_NODECLASS_OBJECT, &c.UA_NODEID_NULL, &parentNodeId, &referenceTypeId, browseName, &typeDefinition, @ptrCast(&attr), &UA_TYPES[c.UA_TYPES_OBJECTATTRIBUTES], null, &result));

    return result;
}

fn getDataType(T: type) *const UA_DataType {
    return switch (T) {
        bool => &UA_TYPES[c.UA_TYPES_BOOLEAN],
        i8 => &UA_TYPES[c.UA_TYPES_SBYTE],
        u8 => &UA_TYPES[c.UA_TYPES_BYTE],
        i16 => &UA_TYPES[c.UA_TYPES_INT16],
        i32 => &UA_TYPES[c.UA_TYPES_INT32],
        i64 => &UA_TYPES[c.UA_TYPES_INT64],
        u16 => &UA_TYPES[c.UA_TYPES_UINT16],
        u32 => &UA_TYPES[c.UA_TYPES_UINT32],
        u64 => &UA_TYPES[c.UA_TYPES_UINT64],
        f32 => &UA_TYPES[c.UA_TYPES_FLOAT],
        f64 => &UA_TYPES[c.UA_TYPES_DOUBLE],
        else => unreachable,
    };
}

fn getCallbacks(T: type) type {
    return struct {
        pub fn read(server: ?*UA_Server, sessionId: ?*const UA_NodeId, sessionContext: ?*anyopaque, nodeId: ?*const UA_NodeId, nodeContext: ?*anyopaque, includeSourceTimestamp: bool, range: ?*const c.UA_NumericRange, value: ?*c.UA_DataValue) callconv(.C) UA_StatusCode {
            // Clear "unused function parameter" warnings
            _ = server;
            _ = sessionId;
            _ = nodeId;
            _ = includeSourceTimestamp;
            _ = sessionContext;
            _ = range;

            // `nodeContext` must contain the image mapped value
            if (nodeContext == null or value == null) {
                return c.UA_STATUSCODE_BADNODATA;
            }

            // Cast to my custom UA_DataValue
            const dst: *UA_DataValue = @ptrCast(@alignCast(value.?));

            const status = UA_Variant_setScalarCopy(&dst.*.value, nodeContext.?, getDataType(T));
            if (c.UA_StatusCode_isBad(status)) {
                return status;
            }

            dst.*.value.storageType = c.UA_VARIANT_DATA_NODELETE;
            dvWrite(dst).hasValue = 1;
            return c.UA_STATUSCODE_GOOD;
        }

        pub fn write(server: ?*UA_Server, sessionId: ?*const UA_NodeId, sessionContext: ?*anyopaque, nodeId: ?*const UA_NodeId, nodeContext: ?*anyopaque, range: ?*const c.UA_NumericRange, value: ?*const c.UA_DataValue) callconv(.C) UA_StatusCode {
            // Clear "unused function parameter" warnings
            _ = server;
            _ = sessionId;
            _ = nodeId;
            _ = sessionContext;
            _ = range;

            // `nodeContext` must contain the image mapped value
            if (nodeContext == null or value == null) {
                return c.UA_STATUSCODE_BADNODATA;
            }

            // Cast to my custom UA_DataValue
            const src: *const UA_DataValue = @ptrCast(@alignCast(value.?));

            if (dvRead(src).hasValue == 1 and src.*.value.data != null) {
                const from: *const T = @alignCast(@ptrCast(src.*.value.data));
                const to: *T = @alignCast(@ptrCast(nodeContext.?));
                to.* = from.*;
                // TODO: msync(xsettings->contents, sizeof(Contents), MS_ASYNC);
            }

            return c.UA_STATUSCODE_GOOD;
        }
    };
}

pub fn bindSetting(server: *UA_Server, folder: UA_NodeId, name: []const u8, description: []const u8, T: type, dst: *T) !void {
    // All strings in `UA_NodeId` are, for some obscure reason,
    // not `const`, so I have to perform these crazy casts
    const cname: [*]u8 = @ptrCast(@constCast(name.ptr));
    const cdescription: [*]u8 = @ptrCast(@constCast(description.ptr));

    const node = c.UA_NODEID_STRING(folder.namespaceIndex, cname);
    const reference = c.UA_NODEID_NUMERIC(0, c.UA_NS0ID_ORGANIZES);
    const browse = c.UA_QUALIFIEDNAME(folder.namespaceIndex, cname);
    const definition = c.UA_NODEID_NUMERIC(0, c.UA_NS0ID_BASEDATAVARIABLETYPE);

    const callbacks = getCallbacks(T);
    const dataSource: c.UA_DataSource = .{
        .read = callbacks.read,
        .write = callbacks.write,
    };

    var attr = c.UA_VariableAttributes_default;
    attr.accessLevel = c.UA_ACCESSLEVELMASK_READ | c.UA_ACCESSLEVELMASK_WRITE;
    attr.displayName = c.UA_LOCALIZEDTEXT(null, cname);
    attr.description = c.UA_LOCALIZEDTEXT(null, cdescription);
    attr.dataType = getDataType(T).typeId;

    // For some reason there is a crash when adding the DataSource
    // variable node. Some facts emerged during the investigation:
    //
    // - UA_Server_addDataSourceVariableNode is a memory hog: it
    //   requires, on my x86_64 system, 360 bytes of stack memory:
    //   8 + 24 + 24 + 24 + 24 + 24 + 200 + 16 + 8 + 8 = 360
    //
    // - if I pass an invalid `node`, e.g. by assigning to ita duplicate
    //   node such as `UA_NODEID_NUMERIC(0, 1)`, the call returns with
    //   an error and no corruption occurs
    //
    // - I added a breakpoint to `UA_Server_addDataSourceVariableNode`:
    //   argument inspection showed that everything up to `attr` seems
    //   correct and everything after it (`dataSource`, `nodeContext`
    //   and `outNewNodeId`) is corrupted
    //
    // - I checked the size of all arguments and they match their C
    //   counterparts
    //
    // - I tried to change, inspect and feed many different arguments
    //   but the crash is always the same
    //
    // - I even tried to replicate the same crash in a MCVE to see if
    //   there is some kind of bug between Zig/C boundaries, but in that
    //   code everything works fine: see `tools/zigc.zig` for details
    //
    // - According to this issue:
    //   https://github.com/open62541/open62541/issues/705
    //   I can use `UA_Server_addVariableNode` and
    //   `UA_Server_setVariableNode_valueCallback` to achieve the same
    //   results, so this is likely my next step
    //
    try fallible(UA_Server_addDataSourceVariableNode(server, node, folder, reference, browse, definition, attr, dataSource, dst, null));
}
