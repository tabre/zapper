const std = @import("std");

const zap = @import("zap");
const Mustache = zap.Mustache;

const clap = @import("clap");

const ViewMaker = @import("view_maker.zig").ViewMaker;

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
        \\-n, --no_route        Disable updating of router
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
    const add_route = res.args.no_route != 1;

    // std.debug.print("Creating {s} view {s} with content type {any} and path {s}\n", .{
    //     if (raw) "raw" else "template",
    //     name,
    //     content_type,
    //     path
    // });

    const view_maker = try ViewMaker.init(alloc, .{
        .name = name,
        .content_type = content_type,
        .url_path = path,
        .raw = raw,
        .overwrite = overwrite,
        .add_route = add_route
    });
    defer view_maker.deinit();
    
    try view_maker.make();
}
