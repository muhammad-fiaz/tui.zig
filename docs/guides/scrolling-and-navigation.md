---
title: Scrolling & Navigation Chrome
description: Combine Header, MenuBar, ContextMenu, Breadcrumbs, Tabs, StatusBar, ScrollView, Scrollbar, and Tree views in tui.zig.
keywords: tui Header, StatusBar, MenuBar, ContextMenu, ScrollView, Tree, Tabs, Breadcrumbs
---

# Scrolling & Navigation Chrome

Build full workstation layouts cleanly using built-in chrome primitives:

- **`Header` & `StatusBar`**: Top application banners and bottom multi-segment bars supporting left/right alignment and inverted badges (`.badge = true`).
- **`MenuBar` & `ContextMenu`**: Horizontal top menu bars paired with `(x, y)` anchored floating shortcut menus and horizontal dividers.
- **`Breadcrumbs` & `Tabs`**: Path indicators (`Home › Docs › Core`) and mouse/keyboard-switchable tab strips (`Tabs.handleEvent`).
- **`ScrollView` + `Scrollbar`**: Bordered viewport container rendering a proportional `Scrollbar` along the right edge whenever `content_height > inner.height` (`Scrollbar.handleEvent` also handles direct mouse wheel & track click/drag).
- **`Tree` + `TreeState`**: Collapsible hierarchical trees using stable path hashing, supporting `const` static or stack `[]const TreeNode` definitions without mutating node slices.
