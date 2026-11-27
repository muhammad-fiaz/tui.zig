const std = @import("std");
const tui = @import("tui");

const State = struct {
    history: [8][64]u8 = undefined,
    history_lens: [8]usize = @splat(0),
    count: usize = 0,
    last_resize: tui.Size = .{ .width = 80, .height = 24 },
};

fn pushLog(state: *State, comptime fmt: []const u8, args: anytype) void {
    const slot = state.count % state.history.len;
    const written = std.fmt.bufPrint(&state.history[slot], fmt, args) catch return;
    state.history_lens[slot] = written.len;
    state.count += 1;
}

fn onEvent(state: *State, event: tui.Event, app: *tui.App) !bool {
    if (event.isCtrlC() or event.isChar('q')) {
        app.quit();
        return false;
    }
    switch (event) {
        .key => |k| {
            if (k.kind == .release) return true;
            switch (k.code) {
                .char => |cp| {
                    var utf8: [4]u8 = undefined;
                    const n = std.unicode.utf8Encode(cp, &utf8) catch 0;
                    pushLog(state, "Key char='{s}' ctrl={} alt={} shift={}", .{
                        utf8[0..n], k.modifiers.ctrl, k.modifiers.alt, k.modifiers.shift,
                    });
                },
                else => pushLog(state, "Key code={s} ctrl={} alt={} shift={}", .{
                    @tagName(k.code), k.modifiers.ctrl, k.modifiers.alt, k.modifiers.shift,
                }),
            }
        },
        .mouse => |m| pushLog(state, "Mouse {s} ({s}) @ ({d},{d})", .{ @tagName(m.kind), @tagName(m.button), m.x, m.y }),
        .resize => |sz| {
            state.last_resize = sz;
            pushLog(state, "Resize -> {d}x{d}", .{ sz.width, sz.height });
        },
        .focus_gained => pushLog(state, "Terminal focus gained", .{}),
        .focus_lost => pushLog(state, "Terminal focus lost", .{}),
        .paste => |p| pushLog(state, "Bracketed paste ({d} bytes)", .{p.len}),
        .tick, .none => {},
    }
    return true;
}

fn render(state: *State, ui: *tui.Ui) !void {
    ui.fillThemeSurface();
    const layout = ui.rows(3, .{ .{ .length = 1 }, .{ .fill = 1 }, .{ .length = 1 } }, .{});

    var hdr = layout[0];
    hdr.header(.{ .title = "Event Inspector", .right = "Press any keys / mouse / paste" }, hdr.area);

    var body = layout[1].margin(tui.Margin.uniform(1));
    try body.panel(.{ .title = "Recent Normalized Events", .focused = true, .padding = tui.Padding.uniform(1) }, body.area, state, struct {
        fn draw(st: *State, p: *tui.Ui) !void {
            if (st.count == 0) {
                try p.paragraph(.{ .raw = "Press keys, click mouse, resize terminal, or paste text..." }, null);
                return;
            }
            const shown = @min(st.count, st.history.len);
            for (0..shown) |i| {
                const idx = (st.count - 1 - i) % st.history.len;
                const slice = st.history[idx][0..st.history_lens[idx]];
                try p.text(slice, .{ .wrap = .none }, p.allocateRows(1));
            }
        }
    }.draw);

    var ft = layout[2];
    ft.statusBar(.{
        .left = &.{.{ .text = "EVENTS", .badge = true }},
        .right = &.{.{ .text = "q / Ctrl+C Quit" }},
    }, ft.area);
}

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const headless = tui.hasArg(init.minimal.args, alloc, "--headless");

    var app = try tui.init(alloc, .{
        .io = init.io,
        .backend = if (headless) .{ .memory = .{ .width = 80, .height = 20 } } else .auto,
        .settings = .{
            .mouse = true,
            .focus_events = true,
        },
    });
    defer app.deinit();

    var state = State{};
    if (headless) {
        _ = try onEvent(&state, .{ .key = .{ .code = .{ .char = 'a' }, .modifiers = tui.KeyModifiers.ctrl_only } }, &app);
        _ = try onEvent(&state, .{ .mouse = .{ .kind = .down, .button = .left, .x = 10, .y = 5 } }, &app);
        try app.draw(&state, render);
        const snap = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap, "ctrl=true") != null);
        return;
    }

    try app.enter();
    try app.run(&state, .{ .onEvent = onEvent, .render = render });
}
