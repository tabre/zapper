const std = @import("std");
const zap = @import("zap");

const View = @import("../view.zig").View;

const HomeData = struct {
    welcome_message: []const u8
};

pub const HomeView = View(HomeData);

pub const home_view = HomeView {
    .path = "/",
    .template_file = "src/views/home.html",
    .get_context = &get_context,
    .content_type = .HTML,
};

fn get_context(view: HomeView, r: zap.Request) HomeData {
    _ = view;
    _ = r;
    
    return HomeData{
        .welcome_message = "Welcome to your new Home view"
    };
}
