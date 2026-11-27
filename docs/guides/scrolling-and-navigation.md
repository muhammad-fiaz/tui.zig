---
title: Scrolling & Navigation Chrome
description: Combine Header, MenuBar, ContextMenu, Breadcrumbs, Tabs, StatusBar, ScrollView, Scrollbar, and Tree views in tui.zig.
keywords: tui Header, StatusBar, MenuBar, ContextMenu, ScrollView, Tree, Tabs, Breadcrumbs
---

# Scrolling & Navigation Chrome

Build full workstation layouts cleanly using built-in chrome primitives:

- **`Header` & `StatusBar`**: Top application banners and bottom multi-segment bars supporting left/right alignment and inverted badges (`.badge = true`).
- **`MenuBar`, `DropdownMenu` & `ContextMenu`**: Horizontal top menu bars, cascading nested submenus (`MenuState`, `MenuGroup`, `MenuItem` with `children` and `checked` toggles), and `(x, y)` anchored floating shortcut menus with horizontal dividers.
- **`Pagination`**: Sliding-window page bar (`�, � Prev  … 4 [5] 6 … 12 Next ▶`) supporting mouse clicks and `Left`/`Right`/`Home`/`End`.
- **`LogViewer` & `DiffViewer`**: Structured log inspector with per-source `EWIDT` target filtering (`h` key), substring match highlighting, and follow-tail scrolling, paired with unified `DiffViewer` old/new line numbers.
- **`TerminalView` (`VtScreen`)**: Pure-Zig ANSI/VT100 screen buffer widget supporting SGR 16/256/RGB colors, cursor tracking, and erase sequences.
- **`Breadcrumbs` & `Tabs`**: Path indicators (`Home › Docs › Core`) and mouse/keyboard-switchable tab strips (`Tabs.handleEvent`).
- **`ScrollView` + `Scrollbar`**: Bordered viewport container rendering a proportional `Scrollbar` along the right edge whenever `content_height > inner.height` (`Scrollbar.handleEvent` also handles direct mouse wheel & track click/drag).
- **`Tree` + `TreeState`**: Collapsible hierarchical trees using stable path hashing, supporting `expandAll`, `collapseAll`, and `const` static or stack `[]const TreeNode` definitions without mutating node slices.

## Cascading `DropdownMenu` Example

```zig
const export_items = [_]tui.MenuItem{
    .{ .label = "Plain Text", .id = "export.txt", .shortcut = "1" },
    .{ .label = "JSON Snapshot", .id = "export.json", .shortcut = "2" },
};
const file_items = [_]tui.MenuItem{
    .{ .label = "New Project", .id = "file.new", .shortcut = "Ctrl+N" },
    .{ .label = "Export As", .children = &export_items },
    .{ .label = "Word Wrap", .id = "view.wrap", .checked = state.word_wrap },
};
const groups = [_]tui.MenuGroup{
    .{ .label = "File", .items = &file_items },
};
try ui.dropdownMenu(.{ .groups = &groups }, &state.menu, bar_area, ui.area);
```
