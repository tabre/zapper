const std = @import("std");


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
    var list: std.ArrayList(u8) = .empty;
    defer list.deinit(a);

    const delimeters = " /.-_\\";
    var prev: u8 = 0;

    for (s, 0..) |c, i| {
        if (std.ascii.isUpper(c)) {
            if (i != 0 and !str_contains_c(delimeters, prev)) try list.append(a, '_');
            try list.append(a, std.ascii.toLower(c));
        } else {
            try list.append(a, c);
        }
        prev = c;
    }

    return list.toOwnedSlice(a);
}

pub fn snake_to_caps(a: std.mem.Allocator, s: []const u8) ![]const u8 {
    var list: std.ArrayList(u8) = .empty;
    var capitalize_next = true;
    const delimeters = " /.-\\";

    for (s) |c| {
        if (c == '_') {
            capitalize_next = true;
        }else if (str_contains_c(delimeters, c)) {
            capitalize_next = true;
            try list.append(a, c);
        } else {
            if (capitalize_next) {
                try list.append(a, std.ascii.toUpper(c));
                capitalize_next = false;
            } else {
                try list.append(a, c);
            }
        }
    }

    return list.toOwnedSlice(a);
}


