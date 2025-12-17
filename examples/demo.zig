const tui = @import("tui");

const Demo = struct {
    pub fn render( ctx: *tui.RenderContext) void {
        var sub = ctx.getSubScreen();
        sub.clear();
        sub.putStringAt(0, 0, "TUI.zig Demo\n\nExamples available in the examples/ directory. Use the demo runner to start them individually.");
    }
};

pub fn main() !void {
    var app = try tui.App.init(.{});
    defer app.deinit();

    const root = Demo{};
    try app.setRoot(&root);
    try app.run();
}
