const std = @import("std");
const tui = @import("tui");

/// Client-defined stateless card widget using `pub fn render(self, ui: *tui.Ui, area: tui.Rect)`.
const MetricBadge = struct {
    title: []const u8,
    value: []const u8,
    delta: []const u8,
    positive: bool = true,

    pub fn render(self: MetricBadge, ui: *tui.Ui, area: tui.Rect) !void {
        const blk = tui.Block{
            .title = self.title,
            .border_type = .rounded,
            .border_style = .{ .foreground = if (self.positive) tui.palette.sky.c500 else tui.palette.rose.c500 },
            .padding = tui.Padding.symmetric(1, 0),
        };
        try blk.render(ui, area);
        const inner = blk.inner(area);
        if (inner.isEmpty()) return;

        _ = ui.buffer.setStringClipped(
            inner.left(),
            inner.top(),
            self.value,
            inner.width,
            .{ .foreground = tui.palette.slate.c50, .bold = true },
            inner,
        );
        if (inner.height >= 2) {
            const delta_s = if (self.positive)
                tui.Style{ .foreground = tui.palette.emerald.c400 }
            else
                tui.Style{ .foreground = tui.palette.rose.c400 };
            _ = ui.buffer.setStringClipped(inner.left(), inner.top() + 1, self.delta, inner.width, delta_s, inner);
        }
    }
};

/// Client-defined stateful rating widget using `pub fn renderStateful(self, ui: *tui.Ui, area: tui.Rect, state: *RatingState)`.
const RatingState = struct {
    stars: u8 = 4,
    max: u8 = 5,
    stars_rect: tui.Rect = tui.Rect.zero,

    pub fn handleEvent(self: *RatingState, event: tui.Event) void {
        switch (event) {
            .key => |k| {
                if (k.kind == .release) return;
                if (k.code == .right and self.stars < self.max) self.stars += 1;
                if (k.code == .left and self.stars > 0) self.stars -= 1;
            },
            .mouse => |m| {
                if (m.isLeftClickInside(self.stars_rect)) {
                    const rel = m.x - self.stars_rect.left();
                    const picked: u8 = @intCast(@min(@as(u16, self.max), rel + 1));
                    self.stars = picked;
                }
            },
            else => {},
        }
    }
};

const StarRating = struct {
    label: []const u8,

    pub fn renderStateful(self: StarRating, ui: *tui.Ui, area: tui.Rect, state: *RatingState) void {
        var pos = ui.buffer.setStringClipped(area.left(), area.top(), self.label, area.width, ui.theme.text, area);
        pos = ui.buffer.setStringClipped(pos.x, area.top(), " ", area.right() -| pos.x, ui.theme.text, area);
        const start_x = pos.x;
        var i: u8 = 0;
        while (i < state.max and pos.x < area.right()) : (i += 1) {
            const sym = if (i < state.stars) "★" else "☆";
            const st = if (i < state.stars)
                tui.Style{ .foreground = tui.palette.amber.c400, .bold = true }
            else
                ui.theme.muted;
            pos = ui.buffer.setStringClipped(pos.x, area.top(), sym, 1, st, area);
        }
        state.stars_rect = tui.Rect.init(start_x, area.top(), pos.x -| start_x, 1);
    }
};

const State = struct {
    rating: RatingState = .{ .stars = 4 },
};

fn onEvent(state: *State, event: tui.Event, app: *tui.App) !bool {
    if (event.isEscape() or event.isCtrlC() or event.isChar('q')) {
        app.quit();
        return false;
    }
    state.rating.handleEvent(event);
    return true;
}

fn render(state: *State, ui: *tui.Ui) !void {
    ui.fillThemeSurface();
    const layout = ui.rows(3, .{ .{ .length = 1 }, .{ .fill = 1 }, .{ .length = 1 } }, .{});
    var hdr = layout[0];
    hdr.header(.{ .title = "Custom Widgets", .right = "Left/Right or Click Stars" }, hdr.area);

    var body = layout[1].margin(tui.Margin.uniform(1));
    if (body.isCompact(54)) {
        try body.renderWidget(MetricBadge{ .title = "Requests/sec", .value = "14,290", .delta = "+12.4% vs 1h" }, body.allocateRows(4));
        body.space(1);
        try body.renderWidget(MetricBadge{ .title = "P99 Latency", .value = "1.8 ms", .delta = "-0.3 ms" }, body.allocateRows(4));
    } else {
        const cards = body.cols(3, .{ .{ .fill = 1 }, .{ .fill = 1 }, .{ .fill = 1 } }, .{ .spacing = .{ .space = 1 } });
        var c0 = cards[0];
        try c0.renderWidget(MetricBadge{ .title = "Requests/sec", .value = "14,290", .delta = "+12.4% vs 1h" }, c0.allocateRows(4));
        var c1 = cards[1];
        try c1.renderWidget(MetricBadge{ .title = "P99 Latency", .value = "1.8 ms", .delta = "-0.3 ms" }, c1.allocateRows(4));
        var c2 = cards[2];
        try c2.renderWidget(MetricBadge{ .title = "Error Rate", .value = "0.02%", .delta = "+0.01%", .positive = false }, c2.allocateRows(4));
        body.space(5);
    }

    try body.renderStateful(StarRating{ .label = "Build Quality Rating:" }, &state.rating, body.allocateRows(2));

    var ft = layout[2];
    ft.statusBar(.{
        .left = &.{.{ .text = "CUSTOM WIDGETS", .badge = true }},
        .right = &.{.{ .text = "Left/Right or Click Rating  q Quit" }},
    }, ft.area);
}

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const headless = tui.hasArg(init.minimal.args, alloc, "--headless");

    var app = try tui.init(alloc, .{
        .io = init.io,
        .backend = if (headless) .{ .memory = .{ .width = 80, .height = 18 } } else .auto,
        .settings = .{ .mouse = true },
    });
    defer app.deinit();

    var state = State{};
    if (headless) {
        try app.draw(&state, render);
        const snap = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap, "14,290") != null);
        std.debug.assert(std.mem.indexOf(u8, snap, "★★★★☆") != null);
        return;
    }

    try app.enter();
    try app.run(&state, .{ .onEvent = onEvent, .render = render });
}
