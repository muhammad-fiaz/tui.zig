---
title: API Reference
description: Complete public API surface of tui.zig v0.1.0 for Zig 0.17.0+.
keywords: tui.zig api reference, zig 0.17.0, tui.App, tui.Ui, tui.widgets, tui.Style
---

# API Reference (`tui`)

Import the root module in your Zig code:

```zig
const tui = @import("tui");
```

Static HTML documentation from Zig doc comments can also be generated locally via `zig build docs` into `zig-out/docs/`.

## Root Re-Exports & Submodules

| Export | Summary | Reference |
|---|---|---|
| `tui.init`, `tui.App`, `tui.AppInfo`, `tui.AppOptions` | Managed runtime, metadata/titles, reusable snapshots, widget factories & backends | [App, Metadata & Backends](/api/app-and-terminal) |
| `tui.Backend`, `tui.TerminalCapabilities` | Cross-platform Win32, POSIX, ANSI, and Memory drivers & capability detection | [App, Metadata & Backends](/api/app-and-terminal) |
| `tui.Ui`, `tui.Buffer`, `tui.Cell`, `tui.Rect`, `tui.Layout`, `tui.Constraint` | Geometry, buffer diffing, constraint splits, render target | [Ui, Buffer & Layout Core](/api/core-and-layout) |
| `tui.Color`, `tui.Style`, `tui.Theme`, `tui.BorderType`, `tui.Span`, `tui.Line`, `tui.Text` | TrueColor/OKLCH models, OKLCH Color palettes, styles, border collapse, text wrapping | [Style, Colors, Themes & Text](/api/style-and-text) |
| `tui.Event`, `tui.KeyEvent`, `tui.MouseEvent`, `tui.EventParser` | Unified keyboard, mouse, paste, resize, and VT parser | [Events & VT Parser](/api/events) |
| `tui.widgets.*`, `tui.Sidebar`, `tui.Navbar`, `tui.DropdownMenu`, `tui.TerminalView`, `tui.Table`, `tui.Chart`, ... | Catalog of 40+ built-in widgets & states | [All Widgets & State Types](/api/widgets) |
| `tui.schema` | Built-in schema validation combinators for settings and inputs | [Forms & Validation](/guides/forms-and-validation) |
| `tui.hasArg` | Cross-platform CLI argument helper (`init.minimal.args`) | [Headless Testing](/guides/testing-and-headless) |
| `tui.version`, `tui.minimum_zig_version` | `"0.1.0"`, `"0.17.0"` |: |
