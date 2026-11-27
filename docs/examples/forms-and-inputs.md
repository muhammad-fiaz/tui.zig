---
title: Forms, Inputs & Validation Examples
description: Examples demonstrating TextInput, TextArea, Switch, Slider, Accordion, Schema validation, Buttons, Checkbox, RadioGroup, and Select dropdowns.
keywords: tui form example, TextInput validation zig, Switch Slider Accordion example, RadioGroup Select
---

# Forms, Inputs & Validation Examples

```sh
zig build run-text-input
zig build run-buttons
zig build run-checkbox
zig build run-radio
zig build run-controls
```

## 1. Validated `TextInput` & `TextArea` (`examples/text_input.zig`)

Combines single-line schema validation (`tui.schema.email`) with a multi-line `TextArea` editor, line numbers, `FocusGroup` tab cycling, hardware cursor tracking, and compact terminal fallbacks:

```text
╭─ Email (live validation) ────────────────────────────────────────────╮
│ dev@tui.zig                                                          │
╰──────────────────────────────────────────────────────────────────────╯

╭─ Multi-line Notes ───────────────────────────────────────────────────╮
│  1 Line 1: Native Zig                                                │
│  2 Line 2: Zero C deps                                               │
╰──────────────────────────────────────────────────────────────────────╯
```

```zig
const EmailSchema = tui.schema.email(.{});

var msg_buf: [128]u8 = undefined;
const val_res = state.email.validateWithSchema(EmailSchema, &msg_buf);
const val_status: tui.ValidationStatus = if (state.email.text().len == 0)
    .none
else if (val_res.valid)
    .valid
else
    .invalid;

try body.textInput(.{
    .label = "Email (live validation)",
    .placeholder = "you@example.com",
    .focused = state.focus.isFocused(0),
    .validation = val_status,
    .error_message = val_res.message,
}, &state.email, state.email_rect);
```

## 2. `RadioGroup` & Expanding `Select` Dropdown (`examples/radio.zig`)

Pairs a bordered `RadioGroup` with a `Select` combobox. Press `Enter` or `Space` to expand the floating option list, `Up`/`Down` to highlight, `Enter`/`Space` to confirm and collapse, or `Esc` to dismiss:

```text
┌─ Deployment Target ───────┐  ╭─ Cloud Region ────────────────────────╮
│ ( ) Development           │  │ us-east-1                           ▾ │
│ (•) Staging               │  ╰───────────────────────────────────────╯
│ ( ) Production            │  ╭───────────────────────────────────────╮
└───────────────────────────┘  │ > us-east-1                           │
                               │   eu-central-1                        │
                               │   ap-southeast-1                      │
                               ╰───────────────────────────────────────╯
```

## 3. Buttons, Checkboxes & Controls

- **`examples/buttons.zig`** (`buttons`): `.primary`, `.success`, `.danger`, and `.outline` button variants with icons, shortcuts, and mouse hitboxes.
- **`examples/checkbox.zig`** (`checkbox`): Boolean checkboxes with click toggling and an aggregated tri-state parent checkbox (`[✓]`, `[-]`, `[ ]`).
- **`examples/controls.zig`** (`controls`): `Switch` ON/OFF pill, continuous `Slider` with wheel/drag support, expandable `Accordion` sections, and semantic `Badge` pills.
