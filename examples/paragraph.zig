const std = @import("std");
const tui = @import("tui");

const State = struct {
    scroll_y: u16 = 0,
    wrap: tui.WrapMode = .word,
};

fn onEvent(state: *State, event: tui.Event, app: *tui.App) !bool {
    switch (event) {
        .key => |k| {
            if (k.isChar('q') or event.isEscape() or event.isCtrlC()) {
                app.quit();
                return false;
            }
            if (k.code == .down or k.isChar('j')) state.scroll_y +|= 1;
            if (k.code == .up or k.isChar('k')) state.scroll_y -|= 1;
            if (k.isChar('w')) {
                state.wrap = switch (state.wrap) {
                    .word => .char,
                    .char => .none,
                    .none => .word,
                };
            }
        },
        else => {},
    }
    return true;
}

fn render(state: *State, ui: *tui.Ui) !void {
    ui.fillThemeSurface();
    const layout = ui.rows(3, .{ .{ .length = 1 }, .{ .fill = 1 }, .{ .length = 1 } }, .{});

    var hdr = layout[0];
    hdr.header(.{ .title = "Paragraph", .subtitle = @tagName(state.wrap), .right = "Up/Down Scroll  w Wrap" }, hdr.area);

    const sample_lines = [_]tui.Line{
        tui.Line.fromSpans(&.{
            tui.Span.styled("tui.zig ", ui.theme.accent.patch(.{ .bold = true })),
            tui.Span.raw("renders rich multi-span paragraphs across word and character boundaries without dropping inline styling."),
        }),
        tui.Line.fromSpans(&.{tui.Span.raw("")}),
        tui.Line.fromSpans(&.{
            tui.Span.styled("Unicode width: ", .{ .bold = true }),
            tui.Span.raw("CJK 漢字, emoji 🚀✨, and combining marks stay column-aligned inside every cell buffer."),
        }),
        tui.Line.fromSpans(&.{tui.Span.raw("")}),
        tui.Line.fromSpans(&.{
            tui.Span.styled("Tab stops: ", ui.theme.info.patch(.{ .bold = true })),
            tui.Span.raw("col1\tcol2\taligned cleanly at tab_size = 4."),
        }),
        tui.Line.fromSpans(&.{tui.Span.raw("")}),
        tui.Line.fromSpans(&.{
            tui.Span.styled("Scrolling: ", ui.theme.success.patch(.{ .bold = true })),
            tui.Span.raw("Press Up/Down or j/k to pan vertically through long documents while `scroll.x` / `scroll.y` track viewport offsets cleanly."),
        }),
    };

    var body = layout[1].margin(tui.Margin.uniform(1));
    try body.paragraph(.{
        .text = tui.Text.fromLines(&sample_lines),
        .block = .{ .title = "Document Reader", .border_type = .rounded, .padding = tui.Padding.uniform(1) },
        .wrap = state.wrap,
        .tab_size = 4,
        .scroll = .{ .y = state.scroll_y },
    }, body.area);

    var ft = layout[2];
    ft.statusBar(.{
        .left = &.{.{ .text = @tagName(state.wrap), .badge = true }},
        .right = &.{.{ .text = "w Cycle Wrap  j/k Scroll  q Quit" }},
    }, ft.area);
}

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const headless = tui.hasArg(init.minimal.args, alloc, "--headless");

    var app = try tui.init(alloc, .{
        .io = init.io,
        .backend = if (headless) .{ .memory = .{ .width = 80, .height = 24 } } else .auto,
    });
    defer app.deinit();

    var state = State{};
    if (headless) {
        try app.draw(&state, render);
        const snap = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap, "Unicode width") != null);
        return;
    }

    try app.enter();
    try app.run(&state, .{ .onEvent = onEvent, .render = render });
}
