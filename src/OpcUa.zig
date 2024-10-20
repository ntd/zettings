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
