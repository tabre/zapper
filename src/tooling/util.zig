const std = @import("std");

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

    pub fn get_stripped_name(self: Self) ?[]const u8 {
        const ldi_opt = std.mem.lastIndexOfScalar(u8, self.name, '.');

        if (ldi_opt) |last_dot_i| {
            return  self.name[0..last_dot_i];
        }

        return self.name;
    }

    pub fn exists(self: Self) bool {
        _ = std.fs.cwd().openFile(self.path, .{}) catch |err| switch(err) {
            error.FileNotFound => return false,
            else => return false
        };

        return true;
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


pub fn lower(a: std.mem.Allocator, s: []const u8) ![]const u8 {
    const buf = try a.alloc(u8, s.len); 
    errdefer a.free(buf);
    return std.ascii.lowerString(buf, s);
}

pub fn str_contains_c(s: []const u8, c: u8) bool {
    for (s) |i| if (i == c) return true;
    return false;
}

pub fn caps_to_snake(a: std.mem.Allocator, s: []const u8) ![]const u8 {
    var list = std.ArrayList(u8).init(a);
    const delimeters = " /.-_\\";
    var prev: u8 = 0;

    for (s, 0..) |c, i| {
        if (std.ascii.isUpper(c)) {
            if (i != 0 and !str_contains_c(delimeters, prev)) try list.append('_');
            try list.append(std.ascii.toLower(c));
        } else {
            try list.append(c);
        }
        prev = c;
    }

    return list.toOwnedSlice();
}

pub fn snake_to_caps(a: std.mem.Allocator, s: []const u8) ![]const u8 {
    var list = std.ArrayList(u8).init(a);
    var capitalize_next = true;
    const delimeters = " /.-\\";

    for (s) |c| {
        if (c == '_') {
            capitalize_next = true;
        }else if (str_contains_c(delimeters, c)) {
            capitalize_next = true;
            try list.append(c);
        } else {
            if (capitalize_next) {
                try list.append(std.ascii.toUpper(c));
                capitalize_next = false;
            } else {
                try list.append(c);
            }
        }
    }

    return list.toOwnedSlice();
}
