const std = @import("std");
const zap = @import("zap");

const View = @import("../view.zig").View;

const JSONData = struct {
    welcome_message: []const u8
};

pub const JSONView = View(JSONData);

pub const json_view = JSONView {
    .path = "/json",
    .template_file = null,
    .get_context = &get_context,
    .content_type = .JSON,
};

fn get_context(view: JSONView, r: zap.Request) JSONData {
    _ = view;
    _ = r;
    
    return JSONData{
        .welcome_message = "Welcome to your new JSON view"
    };
}
