const std = @import("std");
const tui = @import("tui");

const Content = struct {
    lines: [][]const u8,

    pub fn render(self: *Content, ctx: *tui.RenderContext) void {
        var sub = ctx.getSubScreen();
        sub.clear();
        var y: u16 = 0;
        for (self.lines) |line| {
            if (y >= sub.height) break;
            sub.moveCursor(0, y);
            sub.putString(line);
            y += 1;
        }
    }
};

pub const ScrollApp = struct {
    sv: tui.ScrollView(Content) = undefined,
    owned_lines: std.ArrayList([]const u8) = undefined,

    pub fn init() !ScrollApp {
        var owned = try std.ArrayList([]const u8).init(std.heap.page_allocator);
        // Populate some example lines
        for (0..100) |i| {
            const s = try std.fmt.allocPrint(std.heap.page_allocator, "Line {d}", .{i});
            try owned.append(s);
        }
        const content = Content{ .lines = owned.items[0..owned.len] };
        const sv = tui.ScrollView(Content).init(content).withContentSize(80, @as(u16, owned.len));
        return ScrollApp{ .sv = sv, .owned_lines = owned };
    }

    pub fn deinit(self: *ScrollApp) void {
        // Free allocated lines
        for (self.owned_lines.items) |s| {
            std.heap.page_allocator.free(s);
        }
        self.owned_lines.deinit();
    }

    pub fn render(self: *ScrollApp, ctx: *tui.RenderContext) void {
        self.sv.base.bounds = ctx.bounds;
        self.sv.render(ctx);
    }

    pub fn handleEvent(self: *ScrollApp, event: tui.Event) tui.EventResult {
        const res = self.sv.handleEvent(event);
        if (res != .ignored) return .needs_redraw;
        return .ignored;
    }
};

pub fn main() !void {
    var app = try tui.App.init(.{});
    defer app.deinit();

    var root = try ScrollApp.init();
    defer root.deinit();
    try app.setRoot(&root);

    try app.run();
}
