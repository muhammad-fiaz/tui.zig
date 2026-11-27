const std = @import("std");
const tui = @import("tui");

/// Client-defined stateful custom widget (`TagPicker`) plus direct-to-buffer widget
/// (`SparkMetricTile`), showing zero-vtable comptime integration with `ui.renderStateful`
/// and `ui.renderWidget`.
const TagPickerState = struct {
    selected: [6]bool = .{ true, false, true, false, false, false },
    cursor_idx: usize = 0,
    chip_rects: [6]tui.Rect = @splat(tui.Rect.zero),

    pub fn activeCount(self: TagPickerState) usize {
        var count: usize = 0;
        for (self.selected) |s| if (s) {
            count += 1;
        };
        return count;
    }

    pub fn handleEvent(self: *TagPickerState, event: tui.Event, tag_count: usize, focused: bool) bool {
        if (tag_count == 0) return false;
        const n = @min(tag_count, self.selected.len);
        switch (event) {
            .mouse => |m| {
                if (m.kind == .down and m.button == .left) {
                    for (self.chip_rects[0..n], 0..) |rect, i| {
                        if (m.isInside(rect)) {
                            self.cursor_idx = i;
                            self.selected[i] = !self.selected[i];
                            return true;
                        }
                    }
                }
                return false;
            },
            .key => |k| {
                if (!focused or k.kind == .release) return false;
                switch (k.code) {
                    .right, .down => {
                        self.cursor_idx = (self.cursor_idx + 1) % n;
                        return true;
                    },
                    .left, .up => {
                        self.cursor_idx = if (self.cursor_idx == 0) n - 1 else self.cursor_idx - 1;
                        return true;
                    },
                    .enter => {
                        self.selected[self.cursor_idx] = !self.selected[self.cursor_idx];
                        return true;
                    },
                    .char => |cp| {
                        if (cp == ' ') {
                            self.selected[self.cursor_idx] = !self.selected[self.cursor_idx];
                            return true;
                        }
                        return false;
                    },
                    else => return false,
                }
            },
            else => return false,
        }
    }
};

const TagPicker = struct {
    tags: []const []const u8,
    focused: bool = true,
    block: ?tui.Block = .{ .title = "Custom TagPicker Widget", .border_type = .rounded },

    pub fn renderStateful(self: TagPicker, ui: *tui.Ui, area: tui.Rect, state: *TagPickerState) !void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;

        var inner = bounds;
        if (self.block) |blk_base| {
            var blk = blk_base;
            blk.focused = self.focused;
            blk.padding = tui.Padding.uniform(1);
            try blk.render(ui, bounds);
            inner = blk.inner(bounds);
        }
        if (inner.isEmpty()) return;

        var x = inner.left();
        var y = inner.top();
        const limit = @min(self.tags.len, state.selected.len);

        for (self.tags[0..limit], 0..) |tag, i| {
            const checked = state.selected[i];
            const is_cursor = self.focused and state.cursor_idx == i;
            const prefix = if (checked) "[× " else "[+ ";
            const chip_w = tui.text.displayWidth(prefix) +| tui.text.displayWidth(tag) +| 1;

            if (x > inner.left() and x + chip_w > inner.right()) {
                x = inner.left();
                y += 2;
            }
            if (y >= inner.bottom()) {
                state.chip_rects[i] = tui.Rect.zero;
                continue;
            }

            const style: tui.Style = if (is_cursor)
                .{
                    .foreground = tui.palette.slate.c950,
                    .background = tui.palette.amber.c400,
                    .bold = true,
                }
            else if (checked)
                .{
                    .foreground = tui.palette.slate.c950,
                    .background = tui.palette.emerald.c400,
                    .bold = true,
                }
            else
                ui.theme.button;

            const chip_start_x = x;
            x = ui.buffer.setStringClipped(x, y, prefix, inner.right() -| x, style, inner).x;
            x = ui.buffer.setStringClipped(x, y, tag, inner.right() -| x, style, inner).x;
            x = ui.buffer.setStringClipped(x, y, "]", inner.right() -| x, style, inner).x;
            state.chip_rects[i] = tui.Rect.init(chip_start_x, y, x -| chip_start_x, 1);

            if (is_cursor) {
                ui.setCursor(chip_start_x + 1, y);
            }
            if (x < inner.right()) {
                x = ui.buffer.setStringClipped(x, y, " ", 1, ui.theme.surface, inner).x;
            }
        }
    }
};

/// Direct `*tui.Buffer` custom widget demonstrating low-level cell drawing without `*tui.Ui`.
const SparkMetricTile = struct {
    label: []const u8,
    values: []const u8,

    pub fn render(self: SparkMetricTile, buf: *tui.Buffer, area: tui.Rect) void {
        const bounds = area.intersection(buf.area);
        if (bounds.isEmpty()) return;
        const bars = [_][]const u8{ " ", "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█" };
        const end_lbl = buf.setStringClipped(
            bounds.left(),
            bounds.top(),
            self.label,
            bounds.width,
            .{ .foreground = tui.palette.sky.c400, .bold = true },
            bounds,
        );
        var x = end_lbl.x +| 1;
        for (self.values) |v| {
            if (x >= bounds.right()) break;
            const idx: usize = @min(bars.len - 1, v / 32);
            x = buf.setStringClipped(x, bounds.top(), bars[idx], 1, .{ .foreground = tui.palette.teal.c400 }, bounds).x;
        }
    }
};

const tag_names = [_][]const u8{ "zig", "tui", "cross-platform", "unicode", "oklch-palette", "zero-c" };

const State = struct {
    picker: TagPickerState = .{},
};

fn onEvent(state: *State, event: tui.Event, app: *tui.App) !bool {
    if (event.isEscape() or event.isCtrlC() or event.isChar('q')) {
        app.quit();
        return false;
    }
    _ = state.picker.handleEvent(event, tag_names.len, true);
    return true;
}

fn render(state: *State, ui: *tui.Ui) !void {
    ui.fillThemeSurface();
    const layout = ui.rows(3, .{ .{ .length = 1 }, .{ .fill = 1 }, .{ .length = 1 } }, .{});

    var hdr = layout[0];
    hdr.header(.{ .title = "Custom Stateful Widget", .right = "Arrows/Click Toggle Tags" }, hdr.area);

    var body = layout[1].margin(tui.Margin.uniform(1));
    try body.renderStateful(TagPicker{ .tags = &tag_names }, &state.picker, body.allocateRows(8));
    body.space(1);
    try body.renderWidget(SparkMetricTile{
        .label = "Direct Buffer Sparkline:",
        .values = &.{ 32, 64, 128, 96, 160, 224, 250, 180, 120, 210, 240 },
    }, body.allocateRows(2));

    var ft_buf: [48]u8 = undefined;
    const summary = std.fmt.bufPrint(&ft_buf, "Selected tags: {d}/{d}", .{ state.picker.activeCount(), tag_names.len }) catch "";
    var ft = layout[2];
    ft.statusBar(.{
        .left = &.{ .{ .text = "STATEFUL WIDGET", .badge = true }, .{ .text = summary } },
        .right = &.{.{ .text = "Arrows Move  Space/Click Toggle  q Quit" }},
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
        const second_chip = state.picker.chip_rects[1];
        _ = try onEvent(&state, .{ .mouse = .{ .kind = .down, .button = .left, .x = second_chip.left() + 1, .y = second_chip.top() } }, &app);
        try app.draw(&state, render);
        const snap = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap, "Selected tags: 3/6") != null);
        std.debug.assert(std.mem.indexOf(u8, snap, "Direct Buffer Sparkline:") != null);
        return;
    }

    try app.enter();
    try app.run(&state, .{ .onEvent = onEvent, .render = render });
}
