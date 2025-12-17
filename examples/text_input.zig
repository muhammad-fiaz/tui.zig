const std = @import("std");
const tui = @import("tui");

fn on_submit(text: []const u8) void {
    std.debug.print("Submitted: {s}\n", .{text});
}

pub const TextInputApp = struct {
    input: tui.InputField,

    pub fn init() TextInputApp {
        var input = tui.InputField.init(std.heap.page_allocator);
        input = input.withPlaceholder("Type and press Enter");
        input.on_submit = &on_submit;
        return TextInputApp{ .input = input };
    }

    pub fn render(self: *TextInputApp, ctx: *tui.RenderContext) void {
        self.input.base.bounds = ctx.bounds;
        self.input.render(ctx);
    }

    pub fn handleEvent(self: *TextInputApp, event: tui.Event) tui.EventResult {
        const res = self.input.handleEvent(event);
        if (res != .ignored) return .needs_redraw;
        return .ignored;
    }
};

pub fn main() !void {
    var app = try tui.App.init(.{});
    defer app.deinit();

    var root = TextInputApp.init();
    try app.setRoot(&root);
    defer root.input.deinit();

    try app.run();
}
