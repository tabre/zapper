const std = @import("std");
const json = std.json;


pub const ServerConfig = struct {
    interface: []const u8,
    port: u16,
    public_folder: []const u8,
    log: bool,
    threads: i16,
    workers: i16,

    const Self = @This();
    var alloc: ?std.mem.Allocator = null;

    pub fn get_defaults() ServerConfig {
        return Self{
            .interface = "0.0.0.0",
            .port = 3000,
            .public_folder = "public",
            .log = true,
            .threads = 2,
            .workers = 2
        };
    }

    pub fn from_file(a: std.mem.Allocator, f: []const u8) !Self {
        alloc = a;
        const cfg_json = std.fs.cwd().readFileAlloc(a, f, 1048576) catch |e| {
            std.debug.print(
                "{any} Error reading config file: {s}.\nLoading defaults.\n", 
                .{ e, f }
            );
            return Self.get_defaults();
        };
        errdefer a.free(cfg_json);
        
        const cfg_parsed =  json.parseFromSlice(Self, a, cfg_json, .{}) catch |e| {
            std.debug.print(
                "{any} Error reading config file:{s}.\nLoading defaults.\n",
                .{ e, f }
            );
            return Self.get_defaults();
        };
        errdefer cfg_parsed.deinit();
        
        return cfg_parsed.value;
    }

    pub fn get_interface(self: Self) ![*]u8 {
        if (alloc == null) 
            return error.OutOfMemory;

        const a = alloc.?;

        const buf = try a.alloc(u8, self.interface.len);
        errdefer a.free(buf);
        @memcpy(buf, self.interface);

        return buf.ptr;
    }
    
    pub fn get_public_folder(self: Self) ![]u8 {
        if (alloc == null) 
            return error.OutOfMemory;

        const a = alloc.?;

        const buf = try a.alloc(u8, self.public_folder.len);
        errdefer a.free(buf);
        @memcpy(buf, self.public_folder);

        return buf;
    }
};
