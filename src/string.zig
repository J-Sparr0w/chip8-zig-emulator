const mem = @import("std").mem;

pub inline fn startsWith(
    src: []const u8,
    value: []const u8,
) bool {
    return mem.startsWith(u8, src, value);
}

pub inline fn eqls(
    a: []const u8,
    b: []const u8,
) bool {
    return mem.eql(u8, a, b);
}

pub inline fn len(a: []const u8) usize {
    return a.len;
}
