const std = @import("std");
const tui = @import("tui");

pub const CounterApp = struct {
    count: u64 = 0,

    pub fn render(self: *CounterApp, ctx: *tui.RenderContext) void {
        var sub = ctx.getSubScreen();
        sub.clear();
        var buf: [64]u8 = undefined;
        const written = std.fmt.bufPrint(&buf, "Counter: {d}", .{self.count}) catch 0;
        sub.moveCursor(0, 0);
        sub.putString(buf[0..written]);

        sub.moveCursor(0, 2);
        sub.putString("Press '+' to increment, '-' to decrement. Press Ctrl-C to quit.");
    }

    pub fn handleEvent(self: *CounterApp, event: tui.Event) tui.EventResult {
        switch (event) {
            .key => |ke| {
                switch (ke.key) {
                    .char => |c| {
                        if (c == '+') {
                            self.count += 1;
                            return .needs_redraw;
                        } else if (c == '-') {
                            if (self.count > 0) self.count -= 1;
                            return .needs_redraw;
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

    var root = CounterApp{};
    try app.setRoot(&root);

    try app.run();
}
