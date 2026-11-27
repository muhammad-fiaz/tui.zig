const std = @import("std");
const tui = @import("tui");

const presets = [_]struct { name: []const u8, theme: tui.Theme }{
    .{ .name = "Dark", .theme = tui.Theme.dark },
    .{ .name = "Nord", .theme = tui.Theme.nord },
    .{ .name = "Catppuccin", .theme = tui.Theme.catppuccin },
    .{ .name = "Tokyo Night", .theme = tui.Theme.tokyo_night },
    .{ .name = "Gruvbox", .theme = tui.Theme.gruvbox },
    .{ .name = "Dracula", .theme = tui.Theme.dracula },
    .{ .name = "Solarized", .theme = tui.Theme.solarized },
};

const State = struct {
    theme_idx: usize = 0,
};

fn onEvent(state: *State, event: tui.Event, app: *tui.App) !bool {
    switch (event) {
        .key => |k| {
            if (k.isChar('q') or event.isEscape() or event.isCtrlC()) {
                app.quit();
                return false;
            }
            if (k.isChar('t') or k.code == .right or k.code == .tab) {
                state.theme_idx = (state.theme_idx + 1) % presets.len;
                app.setTheme(presets[state.theme_idx].theme);
            }
        },
        else => {},
    }
    return true;
}

fn render(state: *State, ui: *tui.Ui) !void {
    ui.fillThemeSurface();
    const rows = ui.rows(3, .{ .{ .length = 1 }, .{ .fill = 1 }, .{ .length = 1 } }, .{});

    var hdr = rows[0];
    hdr.header(.{ .title = "Styling & Themes", .subtitle = presets[state.theme_idx].name, .right = "t Switch Theme" }, hdr.area);

    const cols = rows[1].cols(2, .{ .{ .percentage = 50 }, .{ .fill = 1 } }, .{ .margin = tui.Margin.uniform(1), .spacing = .{ .space = 1 } });

    var left = cols[0];
    try left.panel(.{ .title = "Text Modifiers & Underlines", .padding = tui.Padding.uniform(1) }, left.area, {}, struct {
        fn draw(_: void, p: *tui.Ui) !void {
            const lines = [_]tui.Line{
                tui.Line.fromSpans(&.{tui.Span.styled("Bold Accent Text", p.theme.accent.patch(.{ .bold = true }))}),
                tui.Line.fromSpans(&.{tui.Span.styled("Italic Muted Description", p.theme.muted.patch(.{ .italic = true }))}),
                tui.Line.fromSpans(&.{tui.Span.styled("Curly Error Underline", p.theme.err.patch(.{ .underline_style = .curly }))}),
                tui.Line.fromSpans(&.{tui.Span.styled("Strikethrough Deprecated", p.theme.muted.patch(.{ .strikethrough = true }))}),
                tui.Line.fromSpans(&.{tui.Span.styled("Reversed Highlight Badge", p.theme.success.patch(.{ .reverse = true }))}),
            };
            try p.paragraph(.{ .text = tui.Text.fromLines(&lines) }, null);
        }
    }.draw);

    var right = cols[1];
    try right.panel(.{ .title = "Active Theme Roles", .focused = true, .padding = tui.Padding.uniform(1) }, right.area, {}, struct {
        fn draw(_: void, p: *tui.Ui) !void {
            try p.button(.{ .label = "Success Action", .variant = .success, .compact = true }, null);
            p.space(1);
            try p.button(.{ .label = "Danger Action", .variant = .danger, .compact = true }, null);
            p.space(1);
            try p.gauge(.{ .ratio = 0.72, .label = "Semantic Accent 72%" }, null);
        }
    }.draw);

    var ft = rows[2];
    ft.statusBar(.{
        .left = &.{.{ .text = presets[state.theme_idx].name, .badge = true }},
        .right = &.{.{ .text = "t / Tab Next Theme  q Quit" }},
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
        _ = try onEvent(&state, .{ .key = .{ .code = .{ .char = 't' } } }, &app);
        try app.draw(&state, render);
        const snap = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap, "Nord") != null);
        return;
    }

    try app.enter();
    try app.run(&state, .{ .onEvent = onEvent, .render = render });
}
