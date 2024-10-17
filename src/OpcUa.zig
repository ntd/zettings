// TODO: for some reason, including `server.h` triggers this error:
//     ...: error: opaque types have unknown size and therefore cannot be directly embedded in structs
//     value: UA_DataValue = @import("std").mem.zeroes(UA_DataValue),
// so, instead, I'm manually declaring all the API I use.
const c = @cImport({
    @cInclude("open62541/types.h");
    //@cInclude("open62541/server.h");
    //@cInclude("open62541/server_config_default.h");
});

// TODO: the following declarations could be dropped
// once server.h can be properly included above
extern fn UA_Server_new() ?*c.UA_Server;
extern fn UA_Server_delete(server: *c.UA_Server) c.UA_StatusCode;
extern fn UA_Server_getConfig(server: *c.UA_Server) ?*c.UA_ServerConfig;
extern fn UA_ServerConfig_setMinimalCustomBuffer(config: ?*c.UA_ServerConfig, portNumber: u16, certificate: ?*const c.UA_ByteString, sendBufferSize: u32, recvBufferSize: u32) c.UA_StatusCode;
extern fn UA_Server_run(server: *c.UA_Server, running: *bool) c.UA_StatusCode;

pub const OPCUAError = error{
    UnableToCreateServer,
    BadStatusCode,
};

fn fallible(status: c.UA_StatusCode) !void {
    if (c.UA_StatusCode_isBad(status)) {
        // TODO: return a more detailed error code
        return OPCUAError.BadStatusCode;
    }
}

pub const Server = struct {
    url: []const u8 = "localhost",
    port: u16 = 4840,

    pub fn start(self: Server) !void {
        const server = UA_Server_new() orelse return OPCUAError.UnableToCreateServer;
        defer _ = UA_Server_delete(server);

        const config = UA_Server_getConfig(server);
        // TODO: use `self.url` in some way
        try fallible(UA_ServerConfig_setMinimalCustomBuffer(config, self.port, null, 0, 0));

        var running = true;
        try fallible(UA_Server_run(server, &running));
    }
};
