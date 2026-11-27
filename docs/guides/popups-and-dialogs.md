---
title: Popups, Modals & Toasts
description: Render centered confirmation dialogs, command palettes, tooltips, backdrop dimming, drop shadows, and corner toast notifications.
keywords: tui popup, ConfirmDialog, CommandPalette, Tooltip, Toast notification zig
---

# Popups, Modals & Toasts

Overlay widgets render last on the root `Ui`, optionally dimming background cells, clearing underlying text with `tui.Clear`, and casting optional drop shadows outside rounded borders.

## Centered Custom `Popup`

```zig
try ui.popup(.{
    .title = "Inspect Deployment",
    .footer_hint = "Esc Close",
    .width_percent = 55,
    .height_percent = 45,
}, null, &state, struct {
    fn draw(st: *State, modal: *tui.Ui) !void {
        try modal.paragraph(.{ .raw = st.details, .wrap = .word }, null);
    }
}.draw);
```

## `ConfirmDialog` & `ConfirmState`

Handle Enter / Esc / Tab / Arrow / `y` / `n` confirmation prompts, or call `handleEventAt(event, app.area(), dialog)` to support direct mouse clicks on Confirm / Cancel buttons:

```zig
if (state.confirm.open) {
    switch (state.confirm.handleEventAt(event, app.area(), confirm_dialog)) {
        .confirmed => try executeDelete(state),
        .cancelled => state.status = "Cancelled",
        .pending => {},
    }
}
```

## `CommandPalette` & `Tooltip`

- `CommandPalette`: modal filterable launcher displaying command names, keyboard shortcuts, and category labels (`Up/Down`, `Enter`, `Esc`, mouse click, wheel scroll, and outside-backdrop click via `handleEventAt`).
- `Tooltip`: compact floating box positioned safely below or above an anchor `Rect`.

## Animated Popups & Auto-Dismiss `ToastState`

Combine `Transition`, `tui.fx.dimBackdrop`, `backdrop_dismiss`, and `ToastState` to animate modals smoothly and expire corner notifications automatically:

```zig
if (event == .tick) {
    const dt = app.deltaMs();
    _ = state.popup_trans.update(dt);
    _ = state.toast.update(dt);
}
```

In `render`:

```zig
if (state.confirm.open or state.popup_trans.isVisible()) {
    tui.fx.dimBackdrop(ui.buffer, ui.area, state.popup_trans.eased() * 0.85);
    const rect = state.popup_trans.animatedRect(confirm_dialog.layout(ui.area).box, .center);
    // render modal within `rect`
}
try state.toast.render(ui, ui.area);
```

### Overflow Protection & Stacked `ToastManager`

`Toast.computeRect(bounds)` word-wraps multi-line messages using `WrapIterator`, reserves drop-shadow margins strictly inside `bounds`, and clamps both X (`xflow`) and Y (`yflow`) so banners never spill past small terminals.

For concurrent non-overlapping notifications, use `tui.ToastManager(capacity)` (`push`, `update(dt_ms)`, `render(ui, bounds)`, `dismissAll`):

```zig
var toasts: tui.ToastManager(4) = .{ .anchor = .bottom_right };
toasts.push("Deployment", "Wrapped cleanly inside terminal bounds.", .success);
```
