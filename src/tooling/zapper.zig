const std = @import("std");

const zap = @import("zap");
const Mustache = zap.Mustache;

const clap = @import("clap");

const lower = @import("util.zig").lower;
const get_new_file = @import("util.zig").get_new_file;

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

fn create_view_source(a: std.mem.Allocator, name: []const u8, content_type: zap.ContentType, path: []const u8, raw: bool) !void {
    const view_name = try lower(a, name);
    defer a.free(view_name);

    const filename = try std.fmt.allocPrint(
        a, "src/views/{s}.zig", .{ view_name }
    );
    defer a.free(filename);
    
    const view_template_file = if (raw) "null" else try std.fmt.allocPrint(
        a, "\"src/views/{s}.html\"", .{ view_name }
    );
    defer if (!raw) a.free(view_template_file);

    const template = try std.fs.cwd().readFileAlloc(a, VIEW_TEMPLATE, TEMPLATE_SIZE); 
    defer a.free(template);

    var mustache = try Mustache.fromData(template);
    defer mustache.deinit();

    if (mustache.build(.{
        .view_name = view_name,
        .view_title = name,
        .content_type = @tagName(content_type),
        .path = path,
        .view_template_file = view_template_file
    }).str()) |rendered| {
        const file = try get_new_file(filename, false);
        try file.seekTo(0);
        try file.writeAll(rendered);
        file.close();
    } else return CreateViewError.ViewTemplateBuildFailed;
}

fn create_view_template_source(a: std.mem.Allocator, name: []const u8) !void {
    const view_name = try lower(a, name);
    defer a.free(view_name);

    const filename = try std.fmt.allocPrint(
        a, "src/views/{s}.html", .{ view_name }
    );
    defer a.free(filename);

    const template = try std.fs.cwd().readFileAlloc(a, TEMPLATE_TEMPLATE, TEMPLATE_SIZE); 
    defer a.free(template);

    const file = try get_new_file(filename, false);
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
        \\
    );

    const parsers = .{
        .name = clap.parsers.string,
        .content_type = clap.parsers.enumeration(zap.ContentType),
        .path = clap.parsers.string,
        .help = clap.parsers.int,
        .raw = clap.parsers.int,
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

    std.debug.print("Creating {s} view {s} with content type {any} and path {s}\n", .{
        if (raw) "raw" else "template",
        name,
        content_type,
        path
    });
    
    try create_view_source(alloc, name, content_type, path, raw);
    if (!raw) try create_view_template_source(alloc, name);
}
