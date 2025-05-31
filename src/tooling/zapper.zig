const std = @import("std");

const zap = @import("zap");
const Mustache = zap.Mustache;

const clap = @import("clap");

const FileInfo = @import("util.zig").FileInfo;
const snake_to_caps = @import("util.zig").snake_to_caps;
const caps_to_snake = @import("util.zig").caps_to_snake;

const VIEW_TEMPLATE = "src/tooling/templates/view.template";
const TEMPLATE_TEMPLATE = "src/tooling/templates/template.template";
const TEMPLATE_SIZE = 1048576;  // 1 MiB

const MainError = error{
    NoCommand,
    InvalidCommand,
};

const CreateViewError = error{
    ViewNameRequired,
    ViewContentTypeRequired,
    ViewPathRequired,
    ViewInvalidContentType,
    ViewTemplateBuildFailed
};

const ZapperError = MainError || CreateViewError;

fn create_view_source(a: std.mem.Allocator, name: []const u8, content_type: zap.ContentType, path: []const u8, raw: bool, overwrite: bool) !void {
    const snake = try caps_to_snake(a, name);
    defer a.free(snake);

    const file_path = try std.fmt.allocPrint(
        a, "src/views/{s}.zig", .{ snake }
    );
    defer a.free(file_path);

    const file_info = try FileInfo.from_path(file_path);
    
    const view_name = file_info.get_stripped_name() orelse return error.Error;
    
    const view_template_file = if (raw) "null" else try std.fmt.allocPrint(
        a, "\"src/views/{s}.html\"", .{ snake }
    );
    defer if (!raw) a.free(view_template_file);

    const template = try std.fs.cwd().readFileAlloc(a, VIEW_TEMPLATE, TEMPLATE_SIZE); 
    defer a.free(template);

    var mustache = try Mustache.fromData(template);
    defer mustache.deinit();

    const view_title = try snake_to_caps(a, view_name);
    defer a.free(view_title);

    if (mustache.build(.{
        .view_name = view_name,
        .view_title = view_title,
        .content_type = @tagName(content_type),
        .path = path,
        .view_template_file = view_template_file
    }).str()) |rendered| {
        const file = try file_info.to_new_file(overwrite);
        try file.seekTo(0);
        try file.writeAll(rendered);
        file.close();
    } else return CreateViewError.ViewTemplateBuildFailed;
}

fn create_view_template_source(a: std.mem.Allocator, name: []const u8, overwrite: bool) !void {
    const snake = try caps_to_snake(a, name);
    defer a.free(snake);

    const file_path = try std.fmt.allocPrint(
        a, "src/views/{s}.html", .{ snake }
    );
    defer a.free(file_path);
    
    const file_info = try FileInfo.from_path(file_path);
    
    const template = try std.fs.cwd().readFileAlloc(a, TEMPLATE_TEMPLATE, TEMPLATE_SIZE); 
    defer a.free(template);

    const file = try file_info.to_new_file(overwrite);
    try file.seekTo(0);
    try file.writeAll(template);

    file.close();
}

fn error_handler(err: anyerror) void {
    const help_msg = "See --help for details.";

    switch (err) {
        error.NoCommand, error.InvalidCommand => {
            std.debug.print(
                "{?}: You must specify a valid command. {s}\n",
                .{ err, help_msg }
            );
        },
        error.ViewNameRequired => {
            std.debug.print(
                "{?}: You must specify a valid name for your view. {s}\n",
                .{ err, help_msg }
            );
        },
        error.ViewContentTypeRequired => {
            std.debug.print(
                "{?}: You must specify a valid content-type for your view. {s}\n",
                .{ err, help_msg }
            );
        },
        error.ViewInvalidContentType => {
            std.debug.print(
                "{?}: You must specify a valid content type. {s}\n",
                .{ err, help_msg }
            );
        },
        else => {
            std.debug.print(
                "{?}: {s}\n",
                .{ err, help_msg }
            );
        }
    }
}

const SubCommands = enum {
    create_view,
};

const main_parsers = .{
    .command = clap.parsers.enumeration(SubCommands),
};

const main_params = clap.parseParamsComptime(
    \\-h, --help    Display this help and exit.
    \\<command>     Command to run (create_view)
    \\
);

fn testing(in: []const u8) void {
    const parse = clap.parsers.enumeration(zap.ContentType);
    const parsed = parse(in);
    return std.debug.print("Content type: {any}", .{ parsed });
}

pub fn main() !void {
    var gpa_state = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = gpa_state.allocator();
    defer _ = gpa_state.deinit();

    var iter = try std.process.ArgIterator.initWithAllocator(gpa);
    defer iter.deinit();

    _ = iter.next();

    var res = clap.parseEx(clap.Help, &main_params, main_parsers, &iter, .{
        .allocator = gpa,
        .terminating_positional = 0,
    }) catch |e| {
        if (e == error.NameNotPartOfEnum)
            return error_handler(ZapperError.InvalidCommand);
        return error_handler(e);
    };
    defer res.deinit();

    if (res.args.help != 0)
        return clap.help(std.io.getStdErr().writer(), clap.Help, &main_params, .{});

    const command = res.positionals[0] orelse return error_handler(ZapperError.InvalidCommand);
    switch(command) {
        .create_view => try create_view(gpa, &iter),
    }
}

fn create_view(alloc: std.mem.Allocator, iter: *std.process.ArgIterator) !void {
    const params = comptime clap.parseParamsComptime(
        \\<name>                Name of the view
        \\<content_type>        Content type (HTML, JSON, TEXT, XHTML, XML)
        \\<path>                URL path
        \\-h, --help            Display this help and exit
        \\-r, --raw             Raw view (no template file)
        \\-o, --overwrite       Overwrite existing files
        \\
    );

    const parsers = .{
        .name = clap.parsers.string,
        .content_type = clap.parsers.enumeration(zap.ContentType),
        .path = clap.parsers.string,
        .help = clap.parsers.int,
        .raw = clap.parsers.int,
        .overwrite = clap.parsers.int,
    };

    var res = clap.parseEx(clap.Help, &params, parsers, iter, .{
        .allocator = alloc
    }) catch |e| {
        if (e == error.NameNotPartOfEnum)
            return error_handler(ZapperError.ViewInvalidContentType);
        return error_handler(e);
    };
    defer res.deinit();

    if (res.args.help == 1)
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
    
    const name = res.positionals[0] orelse 
        return error_handler(ZapperError.ViewNameRequired);

    const content_type = res.positionals[1] orelse
        return error_handler(ZapperError.ViewContentTypeRequired);
    
    const path = res.positionals[2] orelse
        return error_handler(ZapperError.ViewPathRequired);

    const raw = res.args.raw == 1;
    const overwrite = res.args.overwrite == 1;

    std.debug.print("Creating {s} view {s} with content type {any} and path {s}\n", .{
        if (raw) "raw" else "template",
        name,
        content_type,
        path
    });
    
    try create_view_source(alloc, name, content_type, path, raw, overwrite);
    if (!raw) try create_view_template_source(alloc, name, overwrite);
}
