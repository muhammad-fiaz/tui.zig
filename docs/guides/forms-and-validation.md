---
title: Forms & Schema Validation
description: Build validated CLI forms using TextInput, TextArea, Checkbox, RadioGroup, Select, Switch, Slider, and stack-allocated validation rules.
keywords: tui forms, TextInput, TextArea, input validation zig, Switch, Slider, Select
---

# Forms & Schema Validation

**tui.zig** pairs interactive form controls (`TextInput`, `TextArea`, `Checkbox`, `RadioGroup`, `Select`, `Switch`, `Slider`, `Button`) with stack-allocated schema validation (`tui.schema`) so validation runs smoothly on every keystroke without heap allocations.

## Single-Line Input & Hardware Cursor

When `.focused = true`, `TextInput` and `TextArea` scroll horizontally/vertically to keep the caret inside view, highlight active text selections (`Shift+Left`/`Right`/`Home`/`End`, `Ctrl+A`), support `Ctrl+Left`/`Right` word jumps and `Ctrl+K`/`Ctrl+U`/`Ctrl+W` editing shortcuts, and automatically call `ui.setCursor(x, y)` (pairable with `.cursor_shape = .blinking_bar` in `tui.init`).

```zig
const EmailSchema = tui.schema.email(.{});

var err_buf: [128]u8 = undefined;
const check = state.email.validateWithSchema(EmailSchema, &err_buf);
const status: tui.ValidationStatus = if (state.email.text().len == 0)
    .none
else if (check.valid)
    .valid
else
    .invalid;

try ui.textInput(.{
    .label = "Work Email",
    .placeholder = "alex@company.com",
    .focused = state.focus.isFocused(0),
    .validation = status,
    .error_message = check.message,
}, &state.email, null);
```

## Interactive State Controls & Mouse Support

- **`TextInput`** (`TextInput.handleEvent`): Supports click-to-cursor placement, left-button drag text selection, `.disabled` guard, and automatic newline/tab space normalization on insert/paste.
- **`TextArea`** (`TextArea.handleEvent`): Supports `selection_anchor`, `Shift+Arrows`/`Home`/`End` selection ranges, `Ctrl+A`, `selectedText`, `deleteSelection`, `tab_size` expansion (`visualWidthWithTabs`), and `read_only` mode.
- **`Slider`** (`Slider.handleEvent`): Supports `.disabled`, fractional `.precision`, suffix `.unit`, and mouse drag/click aligned cleanly to `Slider.trackRect`.
- **`RadioGroup`**: Supports vertical rows or horizontal items with automatic row wrapping (`.wrap = true`).
- **`Select` / `Dropdown`**: Supports `.disabled`, type-ahead search, keyboard/wheel scrolling, and edge-clamped popup shadows (`Dropdown` and `DropdownState` aliases).

## Presets & Masking

- `tui.TextInput.search("Search files...")`: adds a `🔍 ` prefix
- `tui.TextInput.command("Run command...")`: adds a `> ` prompt prefix
- `tui.TextInput.secret("API Token")`: masks UTF-8 graphemes with `"•"` while keeping raw input bytes in `TextInputState`

## Built-in Validation Combinators

Common validators on `tui.schema` (`string`, `email`, `url`, `integer`, `objectOf`, `withDefault`) check length bounds, formats, and defaults directly on caller stack slices.
