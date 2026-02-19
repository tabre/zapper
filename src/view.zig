const std = @import("std");
const json = std.json;
const math = std.math;

const zap = @import("zap");
const Mustache = zap.Mustache;

const ViewError = @import("errors.zig").ViewError;

const TEMPLATE_SIZE = 1048576;  // 1 MiB

pub fn View(comptime T: type) type {
    return struct {
        path: []const u8,
        template_file: ?[]const u8,
        get_context: *const fn(Self, zap.Request) T,
        content_type: zap.ContentType,
        deinit: *const fn(Self) void,
        
        var alloc: ?std.mem.Allocator = null;
        const Self = @This();

        pub fn has_alloc(self: Self) bool { 
            _ = self;
            return alloc != null; 
        }

        pub fn set_alloc(self: Self, a: std.mem.Allocator) void {
            _ = self;
           alloc = a; 
        }

        pub fn get_alloc(self: Self) ?std.mem.Allocator {
            _ = self;
            return alloc;
        }
        
        pub fn render(self: Self, r: zap.Request) !void {
            const a = alloc.?;
            var template: ?[]const u8 = null;
            defer if (template) |t| a.free(t);
            var ret: []const u8 = undefined;

            const context = self.get_context(self, r);

            if (self.template_file) |tf| {
                template = try std.fs.cwd().readFileAlloc(a, tf, TEMPLATE_SIZE);
            }
            
            if (template) |t| {
                var mustache = try Mustache.fromData(t);
                defer mustache.deinit();

                if (mustache.build(context).str()) |s| {
                   ret = s; 
                } else {
                    // TODO: get better build failure logging from mustache
                    return ViewError.TemplateBuildFailed;
                }

            } else if (self.content_type == zap.ContentType.JSON) {
                ret = try json.Stringify.valueAlloc(a, context, .{});
            }
    
            
            try r.setContentType(self.content_type);
            try r.sendBody(ret);
        }
    };
}
