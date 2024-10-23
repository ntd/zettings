const std = @import("std");
const c = @cImport({
    @cInclude("zigc.h");
});

pub fn main() !void {
    const node = std.mem.zeroes(c.UA_NodeId);
    const name = std.mem.zeroes(c.UA_QualifiedName);
    const attr = std.mem.zeroes(c.UA_VariableAttributes);
    const ds = std.mem.zeroes(c.UA_DataSource);
    _ = c.UA_Server_addDataSourceVariableNode(null, node, node, node, name, node, attr, ds, null, null);
}
