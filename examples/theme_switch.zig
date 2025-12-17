const tui = @import("tui");

pub const ThemeApp = struct {
    app: ?*tui.App,
    current: u8,

    pub fn render(self: *ThemeApp, ctx: *tui.RenderContext) void {
        var sub = ctx.getSubScreen();
        sub.clear();
        sub.putStringAt(0, 0, "Theme switch example - press 't' to toggle theme");
        sub.putStringAt(0, 2, if (self.current == 0) "Current: Default" else if (self.current == 1) "Current: Dark" else "Current: Light");
    }

    pub fn handleEvent(self: *ThemeApp, event: tui.Event) tui.EventResult {
        switch (event) {
            .key => |ke| {
                switch (ke.key) {
                    .char => |c| {
                        if (c == 't') {
                            if (self.app) |a| {
                                if (self.current == 0) {
                                    a.setTheme(tui.Theme.dark);
                                    self.current = 1;
                                } else if (self.current == 1) {
                                    a.setTheme(tui.Theme.light);
                                    self.current = 2;
                                } else {
                                    a.setTheme(tui.Theme.default_theme);
                                    self.current = 0;
                                }
                                return .needs_redraw;
                            }
                        }
                    },
                    else => {},
                }
            },
            else => {},
        }
        return .ignored;
    }
};

pub fn main() !void {
    var app = try tui.App.init(.{});
    defer app.deinit();

    var root = ThemeApp{ .app = &app, .current = 0 };
    try app.setRoot(&root);

    try app.run();
}
