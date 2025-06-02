const std = @import("std");

const zap = @import("zap");
const http = zap.http;

const ServerConfig = @import("config.zig").ServerConfig;
const get_routes = @import("router.zig").get_routes;
pub const View = @import("router.zig").View;

var alloc = std.heap.page_allocator;

const CONFIG_FILE = "config.json";

var routes: std.StringHashMap(View) = undefined;

fn print_headers(headers: zap.Request.HttpParamStrKVList) void {
    std.debug.print("\nREQUEST HEADERS: \n", .{});
    
    for (headers.items) |item| {
        std.debug.print("\t{s}: {s}\n", .{ item.key, item.value }); 
    }

    std.debug.print("\n", .{});
}

fn error_handler(r: zap.Request, code: http.StatusCode, msg: []const u8, err: ?anyerror) void {
    const handling_error_msg = "While handling previous error, another error occurred";
    if (err) |e| {
        if (@errorReturnTrace()) |trace|
            std.debug.print("\nTRACEBACK:{any}", .{ trace });

        if (r.headersToOwnedList(alloc)) |headers| {
            print_headers(headers);
        } else |handling_error| {
            std.debug.print(
                "{s}:\n\nError retrieving retrieving request headers: {any}\n\n",
                .{ handling_error_msg, handling_error }
            );
        }

        std.debug.print("ERROR: {any}\n\n", .{ e });
    }

    if (r.setContentType(.TEXT)) {
        r.setStatus(code);
    } else |handling_error| {
        std.debug.print(
            "{s}:\n\nError while setting content type: {any}",
            .{ handling_error_msg, handling_error }
        );
    }

    r.sendBody(msg) catch return;
}

fn render_view(r: zap.Request, vwu: View) !void {
    switch (vwu) {
        inline else => |view| {
            if (!view.has_alloc())
                view.set_alloc(alloc);

            return try view.render(r);            
        }
    }
}

pub fn dispatcher(r: zap.Request) !void {
    if (r.path) |path| {
        if (routes.get(path)) |vwu| {
            return render_view(r, vwu) catch |err| {
                return error_handler(
                    r, 
                    http.StatusCode.internal_server_error,
                    "Internal Server Error",
                    err
                );
            };
        }

        return error_handler(
            r, 
            http.StatusCode.not_found, 
            "404 Not Found",
            null
        );
    }
    
    return error_handler(
        r,
        http.StatusCode.internal_server_error,
        "Internal Server Error",
        error.NoRequestPath
    );
}

fn on_request(r: zap.Request) !void {
    r.setStatus(.not_found);
    r.sendBody("404 Not Found") catch return;
}

pub fn main() !void {
    const cfg = try ServerConfig.from_file(alloc, CONFIG_FILE);
    
    routes = try get_routes(alloc);

    const cwd = std.fs.cwd().realpathAlloc(alloc, ".") catch ".";
    std.debug.print("Running server from directory: {s}\n", .{ cwd });

    var listener = zap.HttpListener.init(.{
        .interface = try cfg.get_interface(),
        .port = cfg.port,
        .on_request=dispatcher,
        .public_folder = try cfg.get_public_folder(),
        .log = cfg.log,
    });
    try listener.listen();

    std.debug.print("Listening on {s}:{}\n", .{ cfg.interface, cfg.port });

    zap.start(.{
        .threads = cfg.threads,
        .workers = cfg.workers,
    });
}
