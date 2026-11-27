const std = @import("std");
const tui = @import("tui");

const commands = [_]tui.CommandEntry{
    .{ .name = "Switch Theme: Nord", .shortcut = "Alt+1" },
    .{ .name = "Switch Theme: Tokyo Night", .shortcut = "Alt+2" },
    .{ .name = "Open Release Notes", .shortcut = "Alt+R" },
    .{ .name = "Toggle Tooltip", .shortcut = "t" },
    .{ .name = "Quit Demo", .shortcut = "q" },
};

const doc_source =
    \\# tui.zig Release Highlights
    \\
    \\> Native terminal interfaces written cleanly in **Zig 0.17.0+**.
    \\
    \\- Zero C dependencies & explicit `std.mem.Allocator` lifecycle
    \\- OKLCH OKLCH palettes, `Markdown`, `Calendar`, and `CommandPalette`
    \\- Works natively across 32-bit & 64-bit Windows, Linux, and macOS
    \\---
    \\```zig
    \\var app = try tui.init(alloc, .{});
    \\```
;

const State = struct {
    palette: tui.CommandPaletteState,
    show_tooltip: bool = true,
    md_scroll: u16 = 0,
    last_command: []const u8 = "Press p or Ctrl+P to open Command Palette",

    fn deinit(self: *State) void {
        self.palette.deinit();
    }
};

fn onEvent(state: *State, event: tui.Event, app: *tui.App) !bool {
    if (event.isCtrlC()) {
        app.quit();
        return false;
    }
    if (state.palette.open) {
        switch (try state.palette.handleEventAt(event, app.area(), &commands)) {
            .executed => |idx| {
                state.last_command = commands[idx].name;
                switch (idx) {
                    0 => app.setTheme(tui.Theme.nord),
                    1 => app.setTheme(tui.Theme.tokyo_night),
                    3 => state.show_tooltip = !state.show_tooltip,
                    4 => {
                        app.quit();
                        return false;
                    },
                    else => {},
                }
            },
            .cancelled => state.last_command = "Palette dismissed",
            .none => {},
        }
        return true;
    }

    if (event.isEscape() or event.isChar('q')) {
        app.quit();
        return false;
    }
    if (event.isChar('p') or (event == .key and event.key.isCtrl('p'))) {
        state.palette.toggle();
    } else if (event.isChar('t')) {
        state.show_tooltip = !state.show_tooltip;
    } else if (event == .key and event.key.kind != .release) {
        switch (event.key.code) {
            .down => state.md_scroll +|= 1,
            .up => state.md_scroll -|= 1,
            .page_down => state.md_scroll +|= 4,
            .page_up => state.md_scroll -|= 4,
            .char => |cp| {
                if (cp == 'j') state.md_scroll +|= 1;
                if (cp == 'k') state.md_scroll -|= 1;
            },
            else => {},
        }
    }
    return true;
}

fn render(state: *State, ui: *tui.Ui) !void {
    ui.fillThemeSurface();
    const layout = ui.rows(4, .{
        .{ .length = 1 },
        .{ .length = 6 },
        .{ .fill = 1 },
        .{ .length = 1 },
    }, .{});

    var hdr = layout[0];
    hdr.header(.{ .title = "BigText, Markdown & CommandPalette", .right = "p Palette  t Tooltip" }, hdr.area);

    var banner = layout[1].margin(tui.Margin.symmetric(2, 0));
    try banner.bigText(.{ .text = "TUI.ZIG", .alignment = .center }, banner.area);

    var body = layout[2].margin(tui.Margin.symmetric(2, 0));
    try body.markdown(.{
        .source = doc_source,
        .scroll_y = state.md_scroll,
        .block = .{ .title = "Markdown Viewer (Up/Down Scroll)", .padding = tui.Padding.uniform(1) },
    }, body.area);

    var ft = layout[3];
    ft.statusBar(.{
        .left = &.{ .{ .text = "PALETTE", .badge = true }, .{ .text = state.last_command } },
        .right = &.{.{ .text = "p Palette  t Tip  q Quit" }},
    }, ft.area);

    // Anchor tooltip right above the bottom status bar so the BigText header stays clear.
    if (state.show_tooltip and !state.palette.open) {
        try ui.tooltip(.{
            .text = "Tip: Press p / Ctrl+P for Palette",
            .anchor_rect = tui.Rect.init(2, ft.area.top(), 20, 1),
        }, null);
    }

    if (state.palette.open) {
        try ui.commandPalette(.{ .commands = &commands }, &state.palette, null);
    }
}

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const headless = tui.hasArg(init.minimal.args, alloc, "--headless");

    var app = try tui.init(alloc, .{
        .io = init.io,
        .backend = if (headless) .{ .memory = .{ .width = 84, .height = 24 } } else .auto,
        .settings = .{ .mouse = true },
    });
    defer app.deinit();

    var state = State{ .palette = app.commandPalette() };
    defer state.deinit();

    if (headless) {
        state.palette.open = true;
        try app.draw(&state, render);
        const snap = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap, "Switch Theme: Nord") != null);
        std.debug.assert(std.mem.indexOf(u8, snap, "[Alt+1]") != null);
        return;
    }

    try app.enter();
    try app.run(&state, .{ .onEvent = onEvent, .render = render });
}
