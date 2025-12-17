const tui = @import("tui");

const Left = struct {
    pub fn render( ctx: *tui.RenderContext) void {
        var sub = ctx.getSubScreen();
        sub.clear();
        sub.putStringAt(0, 0, "Left pane");
    }
};

const Right = struct {
    pub fn render( ctx: *tui.RenderContext) void {
        var sub = ctx.getSubScreen();
        sub.clear();
        sub.putStringAt(0, 0, "Right pane");
    }
};

pub const SplitApp = struct {
    sv: tui.SplitView(Left, Right) = undefined,

    pub fn init() SplitApp {
        return SplitApp{ .sv = tui.SplitView(Left, Right).horizontal(Left{}, Right{}) };
    }

    pub fn render(self: *SplitApp, ctx: *tui.RenderContext) void {
        self.sv.base.bounds = ctx.bounds;
        self.sv.render(ctx);
    }

    pub fn handleEvent(self: *SplitApp, event: tui.Event) tui.EventResult {
        const res = self.sv.handleEvent(event);
        if (res != .ignored) return .needs_redraw;
        return .ignored;
    }
};

pub fn main() !void {
    var app = try tui.App.init(.{});
    defer app.deinit();

    var root = SplitApp.init();
    try app.setRoot(&root);

    try app.run();
}
