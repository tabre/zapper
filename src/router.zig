const std = @import("std");
const zap = @import("zap");

// Import views
const home_view = @import("views/home.zig").home_view;
const HomeView = @import("views/home.zig").HomeView;

const json_view = @import("views/json.zig").json_view;
const JSONView = @import("views/json.zig").JSONView;

// All view types go here
pub const View = union(enum) {
    HomeView: HomeView,
    JSONView: JSONView
};

// Register routes for views
pub fn get_routes(alloc: std.mem.Allocator) !std.StringHashMap(View) {
    var routes = std.StringHashMap(View).init(alloc);

    // All views go here
    try routes.put(home_view.path, View{ .HomeView = home_view});
    try routes.put(json_view.path, View{ .JSONView = json_view});
    
    return routes;
}

