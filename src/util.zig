const std = @import("std");

pub fn to_c_str(a: std.mem.Allocator, s: []const u8) ![]u8 {
    const buf = try a.alloc(u8, s.len);
    errdefer a.free(buf);
    @memcpy(buf, s);
    return buf;
}
