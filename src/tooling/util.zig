const std = @import("std");


pub fn lower(a: std.mem.Allocator, s: []const u8) ![]const u8 {
    const buf = try a.alloc(u8, s.len); 
    errdefer a.free(buf);
    return std.ascii.lowerString(buf, s);
}

fn file_exists(path: []const u8) bool {
    _ = std.fs.cwd().openFile(path, .{}) catch |err| switch(err) {
        error.FileNotFound => return false,
        else => return false
    };

    return true;
}

pub fn get_new_file(path: []const u8, overwrite: ?bool) !std.fs.File {
    const ow = overwrite orelse false; 
    if (!ow and file_exists(path)) return error.FileExists;

    const last_slash_i = std.mem.lastIndexOfScalar(u8, path, '/') orelse 
        return error.InvalidPath;

    const dir = path[0..last_slash_i];

    try std.fs.cwd().makePath(dir);

    const file = try std.fs.cwd().createFile(
        path,
        .{ .read = true, }
    );

    return file;
}
