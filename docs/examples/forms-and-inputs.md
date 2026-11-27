---
title: Forms, Inputs & Validation
description: Self-contained examples for TextInput schema validation, multi-line TextArea, RadioGroup, expanding Select dropdowns, Switch, Slider, and Accordion.
keywords: tui form example, TextInput validation zig, Switch Slider Accordion example, RadioGroup Select
---

# Forms, Inputs & Validation

## 1. Live-Validated `TextInput` & Multi-Line `TextArea`

**Use case:** Settings forms, login screens, and note editors with real-time schema validation, line numbers, and hardware cursor positioning.

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

fn renderForm(state: *FormState, ui: *tui.Ui) !void {
    var msg_buf: [128]u8 = undefined;
    const val = state.email.validateWithSchema(EmailSchema, &msg_buf);
    const status: tui.ValidationStatus = if (state.email.text().len == 0)
        .none
    else if (val.valid)
        .valid
    else
        .invalid;

    try ui.textInput(.{
        .label = "Email (live validation)",
        .placeholder = "you@example.com",
        .focused = state.focus.isFocused(0),
        .validation = status,
        .error_message = val.message,
    }, &state.email, state.email_rect);

    try ui.textArea(.{
        .block = .{ .title = "Multi-line Notes", .border_type = .rounded },
        .placeholder = "Write notes here...",
        .focused = state.focus.isFocused(1),
        .line_numbers = true,
    }, &state.notes, state.notes_rect);
}
```

## 2. `RadioGroup` & Expanding `Select` Dropdown

**Use case:** Environment selectors and configuration forms where a compact combobox expands into a floating option menu on `Enter`, `Space`, or click.

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

```zig
const envs = [_][]const u8{ "Development", "Staging", "Production" };
const regions = [_][]const u8{ "us-east-1", "eu-central-1", "ap-southeast-1" };

try left.radio(.{ .items = &envs, .block = .{ .title = "Deployment Target" }, .focused = !state.focus_select }, &state.env_radio, left.area);
try right.select(.{ .items = &regions, .label = "Cloud Region", .focused = state.focus_select }, &state.region_select, right.allocateRows(3));
```

## 3. `Switch`, `Slider` & `Accordion`

**Use case:** Collapsible configuration sections paired with binary toggles and numeric range sliders.

```zig
ui.switchToggle(.{ .label = "Auto Canary Promotion", .on = state.auto_deploy }, null);
try ui.slider(.{ .label = "Replicas", .precision = 0, .unit = " pods" }, &state.replicas, null);
try ui.accordion(.{ .title = "Advanced Network", .expanded = state.net_open }, null, state, drawNetworkBody);
```
