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

## Validated Input + Multi-line Editor (`examples/text_input.zig`)

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
}, &state.email, null);
```

Both `TextInputState` and `TextAreaState` handle grapheme-safe cursor navigation (`Left`/`Right`/`Home`/`End`/`Ctrl+A`/`Ctrl+E`), `Backspace`/`Delete`, `Ctrl+U`/`Ctrl+W`, bracketed paste, hardware cursor positioning, and horizontal/vertical viewport scrolling.
