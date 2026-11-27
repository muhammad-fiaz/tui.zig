---
layout: home
title: Native Terminal User Interfaces for Zig
description: tui.zig is a production-ready terminal user interface library written cleanly in Zig 0.17.0+ with double-buffered diff rendering, explicit allocators, OKLCH Color palettes, 40+ widgets, and pure Zig media viewers.
keywords: zig, zig 0.17.0, tui.zig, terminal ui, zig tui framework, OKLCH oklch, cross-platform terminal, custom widgets

hero:
  name: tui.zig
  text: Native Terminal UIs in Pure Zig
  tagline: Double-buffered diff rendering, explicit allocators, constraint layouts, OKLCH Color palettes, 40+ composable widgets, i18n, and native media viewers built for Zig 0.17.0+.
  actions:
    - theme: brand
      text: Get Started
      link: /guides/getting-started
    - theme: alt
      text: Explore Widgets & Examples
      link: /examples/
    - theme: alt
      text: API Reference
      link: /api/

features:
  - icon: ⚡
    title: Zero Steady-State Frame Allocations
    details: Double-buffered cell grids and capacity-retaining scratch arenas render interactive interfaces smoothly without heap churn between redraws.
  - icon: 📐
    title: Constraint Solver & Responsive Splits
    details: Mix fixed lengths, percentages, ratios, min/max bounds, weighted fills, flex spacing, and responsive breakpoints with zero hidden allocations.
  - icon: 🖥️
    title: Native Cross-Platform Backends
    details: Uses Win32 Console APIs on Windows and native POSIX termios/poll/TIOCGWINSZ/SIGWINCH on Linux, macOS, and BSD (32-bit & 64-bit), plus headless memory rendering.
  - icon: 🎨
    title: OKLCH Color & 17 Themes
    details: Built-in TrueColor RGB/HSL/HSV/Hex/OKLCH colors, official OKLCH Color color families, perceptual ANSI-256/16 degradation, and 17 built-in theme presets.
  - icon: 🧩
    title: 40+ Widgets, App Shell Layouts & Media
    details: Panels, Navbar, Left/Right RTL Sidebar, DropdownMenu, StatusBar, Markdown, Tables, Pie/Area/Step Charts, Heatmaps, Log/Diff Viewers, TerminalView, Custom Fonts, and Locale i18n.
  - icon: 🧪
    title: Deterministic Headless Verification
    details: Inject synthetic key, mouse, paste, and resize events and inspect screen snapshots or cursor state directly inside std.testing or --headless CI binaries.
---

## Quick Example

```zig
const std = @import("std");
const tui = @import("tui");

const State = struct {
    progress: f64 = 0.65,
};

fn render(state: *State, ui: *tui.Ui) !void {
    ui.fillThemeSurface();
    const layout = ui.rows(3, .{ .{ .length = 1 }, .{ .fill = 1 }, .{ .length = 1 } }, .{});

    var hdr = layout[0];
    hdr.header(.{ .title = "tui.zig", .subtitle = "Overview", .right = "v" ++ tui.version }, hdr.area);

    var body = layout[1].margin(tui.Margin.uniform(1));
    try body.panel(.{ .title = "Status", .focused = true, .padding = tui.Padding.uniform(1) }, body.area, state, struct {
        fn draw(st: *State, p: *tui.Ui) !void {
            try p.paragraph(.{
                .raw = "Declarative flat helpers or structured widgets over the exact same double-buffered cell grid.",
                .wrap = .word,
            }, null);
            p.space(1);
            try p.gauge(.{ .ratio = st.progress, .label = "Build 65%" }, null);
        }
    }.draw);

    var ft = layout[2];
    ft.statusBar(.{
        .left = &.{.{ .text = "READY", .badge = true }},
        .right = &.{.{ .text = "q / Esc Quit" }},
    }, ft.area);
}

pub fn main(init: std.process.Init) !void {
    var app = try tui.init(init.gpa, .{ .io = init.io });
    defer app.deinit();

    var state = State{};
    try app.enter();
    try app.run(&state, .{ .render = render });
}
```
