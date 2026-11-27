---
title: Stateful Widgets
description: Manage selection, scroll offsets, expand/collapse trees, command palettes, sliders, calendars, and focus rings across frames.
keywords: tui stateful widgets, ListState, TableState, TreeState, TextInputState, FocusGroup
---

# Stateful Widgets

Stateless widgets only borrow configuration each frame. Stateful widgets store selection indices, scroll positions, expanded node sets, and editable buffers cleanly in **caller-owned state structs**.

## Core Stateful Pairs

| Widget | State Type | Cleanup Needed? |
|---|---|---|
| `List` | `tui.ListState` | No (value struct) |
| `Table` | `tui.TableState` | No (value struct) |
| `Scrollbar` | `tui.ScrollbarState` | No (value struct) |
| `ScrollView` | `tui.ScrollViewState` | No (value struct) |
| `RadioGroup` | `tui.RadioState` | No (value struct) |
| `Select` | `tui.SelectState` | No (value struct) |
| `Slider` | `tui.SliderState` | No (value struct) |
| `Calendar` | `tui.CalendarState` | No (value struct) |
| `ConfirmDialog` | `tui.ConfirmState` | No (value struct) |
| `TextInput` | `tui.TextInputState` | Yes (`defer state.deinit()`) |
| `TextArea` | `tui.TextAreaState` | Yes (`defer state.deinit()`) |
| `Tree` | `tui.TreeState` | Yes (`defer state.deinit()`) |
| `CommandPalette` | `tui.CommandPaletteState` | Yes (`defer state.deinit()`) |
| `TerminalView` | `tui.VtScreen` | Yes (`defer screen.deinit()`) |

## Expand / Collapse Controls

- **`TreeState`**: Call `try state.expandAll(&roots)` / `state.collapseAll()`, or toggle individual branches via `Enter`, `Space`, `Left`/`Right`, or mouse double-click (`handleEvent`).
- **`Select` / `Dropdown`**: Expand/collapse via `Enter`, `Space`, `Down` (when closed), `Esc` (to collapse), or clicking the header/outside (`SelectState.handleEventIn`).
- **`Accordion`**: Toggle `.expanded` per section on click, `Enter`, or `Space` (`Accordion.handleEvent`).

## Scroll-Synchronized Rendering

When rendering a `List`, `Table`, or `Tree`, the widget inspects `state.selected` alongside the inner viewport height and updates `state.offset` automatically so the active item stays visible across resizes:

```zig
try ui.list(.{
    .raw_items = &items,
    .block = .{ .title = "Packages", .focused = true },
}, &state.list, list_rect);
```

## Focus Coordination (`FocusGroup`)

Coordinate multi-control screens cleanly with `tui.FocusGroup`:

```zig
var focus = tui.FocusGroup{ .count = 3 };
if (focus.handleEvent(event)) return true; // Consumes Tab / BackTab
```
