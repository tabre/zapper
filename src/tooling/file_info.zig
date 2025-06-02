const std = @import("std");

const TEMPLATE_SIZE = 1048576;  // 1 MiB

pub const FileInfo = struct {
    dir: ?[]const u8,
    name: []const u8,
    path: []const u8,

    const Self = @This();

    pub fn from_path(path: []const u8) !Self {
        if (path.len < 1) return error.BadPath;
        
       const lsi_opt = std.mem.lastIndexOfScalar(u8, path, '/');

       if (lsi_opt) |last_slash_i| {
            return Self{
                .dir = path[0..last_slash_i],
                .name = path[last_slash_i + 1..],
                .path = path
            };
        } else {
            return Self{ .dir = null, .name = path, .path = path };
        }
    }

    pub fn exists(self: Self) bool {
        _ = std.fs.cwd().openFile(self.path, .{}) catch |err| switch(err) {
            error.FileNotFound => return false,
            else => return false
        };

        return true;
    }

    pub fn read_file(self: Self, a: std.mem.Allocator) ![]const u8 {
        return try std.fs.cwd().readFileAlloc(a, self.path, TEMPLATE_SIZE);
    }

    pub fn to_new_file(self: Self, overwrite: bool) !std.fs.File {
        if (self.exists()) {
            if (overwrite) {
               std.debug.print(
                   "Overwrite flag is set. Opening existing file: {s}\n", 
                   .{ self.path }
                ); 
            } else {
                return error.FileExists;
            }
        }

        try std.fs.cwd().makePath(self.dir orelse return error.BadPath);

        return try std.fs.cwd().createFile(
            self.path,
            .{ .read = true, }
        );
    }
};
