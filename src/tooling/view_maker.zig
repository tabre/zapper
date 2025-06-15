const std = @import("std");
 
const zap = @import("zap");
const Mustache = zap.Mustache;

const FileInfo = @import("file_info.zig").FileInfo;
const snake_to_caps = @import("util.zig").snake_to_caps;
const caps_to_snake = @import("util.zig").caps_to_snake;

const VIEW_TEMPLATE = "src/tooling/templates/view.template";
const TEMPLATE_TEMPLATE = "src/tooling/templates/template.template";
const ROUTER_FILE = "src/router.zig";

const CreateViewSourceError = error{
    ViewTemplateBuildFailed
};

const CreateViewTemplateSourceError = error {
};

const ViewMakerError = CreateViewSourceError || CreateViewTemplateSourceError;

pub const ViewMakerArgs = struct {
    name: []const u8,
    content_type: zap.ContentType,
    url_path: []const u8,
    raw: bool,
    overwrite: bool,
    add_route: bool
};

pub const ViewMaker = struct {
    view_template: FileInfo,
    view_out: FileInfo,
    template_template: ?FileInfo,
    template_out: ?FileInfo,
    router_file: FileInfo,
    view_struct_name: []const u8,
    data_struct_name: []const u8,
    view_instance_name: []const u8,
    url_path: []const u8,
    content_type: []const u8,
    raw: bool,
    overwrite: bool,
    add_route: bool,

    const Self = @This();
    var alloc: std.mem.Allocator = undefined;

    pub fn init(a: std.mem.Allocator, o: ViewMakerArgs) !Self {
        alloc = a;

        const snake = try caps_to_snake(a, o.name);
        defer alloc.free(snake);
        
        var base_name: []const u8 = undefined;
        if (std.mem.lastIndexOfScalar(u8, snake, '/')) |last_slash_i| {
            base_name = snake[last_slash_i + 1..];
        } else {
            base_name = snake;
        }

        const base_name_caps = try snake_to_caps(alloc, base_name); 
        defer alloc.free(base_name_caps);

        return Self{
            .view_template = try FileInfo.from_path(VIEW_TEMPLATE),
            .view_out = try FileInfo.from_path(try std.fmt.allocPrint(
                a, "src/views/{s}.zig", .{ snake }
            )),
            .template_template = if (o.raw) null
                else try FileInfo.from_path(TEMPLATE_TEMPLATE),
            .template_out = if (o.raw) null 
                else try FileInfo.from_path(try std.fmt.allocPrint(
                    a, "src/views/{s}.html", .{ snake }
            )),
            .router_file = try FileInfo.from_path(ROUTER_FILE),
            .view_struct_name = try std.fmt.allocPrint(alloc, "{s}View", .{ base_name_caps }),
            .data_struct_name = try std.fmt.allocPrint(alloc, "{s}Data", .{ base_name_caps }),
            .view_instance_name = try std.fmt.allocPrint(alloc, "{s}_view", .{ base_name }),
            .url_path = o.url_path,
            .content_type = @tagName(o.content_type),
            .raw = o.raw,
            .overwrite = o.overwrite,
            .add_route = o.add_route,
        };
    }

    fn get_view_relative_root_path(self: Self) !std.ArrayList(u8) {
        var count: usize = 1;
        for (self.view_out.path) |c| { if (c == '/') count += 1; }
    
        var list = std.ArrayList(u8).init(alloc);

        for (0..count - 2) |_|  {
            try list.appendSlice("../");
        }

        return list;
    }

    fn create_view_source(self: Self) !void {
        const template = try self.view_template.read_file(alloc);        
        defer alloc.free(template);

        var mustache = try Mustache.fromData(template);
        defer mustache.deinit();

        const view_template_file = if (self.raw) "null" 
                else try std.fmt.allocPrint(alloc, "\"{s}\"", .{ self.template_out.?.path });
        defer if (!self.raw) alloc.free(view_template_file);

        const relative_root_path = try self.get_view_relative_root_path();
        defer relative_root_path.deinit();

        if (mustache.build(.{
            .relative_root_path = relative_root_path.items,
            .view_struct_name = self.view_struct_name,
            .data_struct_name = self.data_struct_name,
            .view_instance_name =  self.view_instance_name,
            .view_template_file = view_template_file,
            .url_path = self.url_path,
            .content_type = self.content_type,
        }).str()) |rendered| {
            const file = try self.view_out.to_new_file(self.overwrite);
            try file.seekTo(0);
            try file.writeAll(rendered);
            file.close();
        } else return ViewMakerError.ViewTemplateBuildFailed;
    }

    fn create_view_template_source(self: Self) !void {
        const template = try self.template_template.?.read_file(alloc); 
        defer alloc.free(template);

        const file = try self.template_out.?.to_new_file(self.overwrite);
        try file.seekTo(0);
        try file.writeAll(template);

        file.close();
    }

    fn update_router(self: Self) !void {
        const template = try self.router_file.read_file(alloc);        
        defer alloc.free(template);

        var mustache = try Mustache.fromData(template);
        defer mustache.deinit();

        const import_path = self.view_out.path[4..]; 

        const import_lines = try std.fmt.allocPrint(
            alloc, 
            \\
            \\
            \\const {s} = @import("{s}").{s};
            \\const {s} = @import("{s}").{s};  // {{{{{{import_lines}}}}}}
            ,.{
                self.view_instance_name,
                import_path,
                self.view_instance_name,
                self.view_struct_name,
                import_path,
                self.view_struct_name
            }
        );
        defer alloc.free(import_lines);

        const enum_line = try std.fmt.allocPrint(
            alloc, 
            \\
            \\    {s}: {s}  // {{{{{{enum_line}}}}}}
            ,.{
                self.view_struct_name,
                self.view_struct_name
            }
        );
        defer alloc.free(enum_line);
        
        const route_line = try std.fmt.allocPrint(
            alloc, 
            \\
            \\    try routes.put({s}.path, View{{ .{s} = {s} }});  // {{{{{{route_line}}}}}}
            ,.{
                self.view_instance_name,
                self.view_struct_name,
                self.view_instance_name
            }
        );
        defer alloc.free(route_line);

        if (mustache.build(.{
            .import_lines = import_lines,
            .enum_line = enum_line,
            .route_line = route_line,
        }).str()) |rendered| {
            const file = try self.router_file.to_new_file(true);
            try file.seekTo(0);
            try file.writeAll(rendered);
            file.close();
        } else return ViewMakerError.ViewTemplateBuildFailed;
    }

    pub fn make(self: Self) !void {
        try self.create_view_source();
        if (!self.raw) try self.create_view_template_source();
        if (self.add_route) try self.update_router();
        return;
    }

    pub fn deinit(self: Self) void {
        alloc.free(self.view_struct_name);
        alloc.free(self.data_struct_name);
        alloc.free(self.view_instance_name);
        alloc.free(self.view_out.path);
        if (!self.raw) alloc.free(self.template_out.?.path);
    }
};
