---
title: Events, Keys & Mouse Input
description: Handle normalized keyboard chords, UTF-8 characters, mouse clicks/scrolls, resizes, focus events, and bracketed pastes.
keywords: tui events, KeyEvent, MouseEvent, Kitty keyboard protocol, SGR mouse, bracketed paste
---

# Events, Keys & Mouse Input

All input events arrive through `tui.Event`, unified identically across Windows Console APIs, POSIX VT streams, and `MemoryBackend`.

## `tui.Event` Variants

```zig
pub const Event = union(enum) {
    key: KeyEvent,
    mouse: MouseEvent,
    resize: Size,
    focus_gained,
    focus_lost,
    paste: []const u8,
    tick,
    none,
};
```

## Keyboard & Mouse Matching Helpers

```zig
fn onEvent(state: *State, event: tui.Event, app: *tui.App) !bool {
    if (event.isEscape() or event.isCtrlC() or event.isChar('q')) {
        app.quit();
        return false;
    }
    switch (event) {
        .key => |k| {
            if (k.kind == .release) return true;
            if (k.isCtrl('s')) try saveWorkspace(state);
            if (k.code == .down) state.list.selectNext(state.items.len);
        },
        .mouse => |m| {
            if (m.isLeftClickInside(state.save_btn_rect)) try saveWorkspace(state);
            if (m.kind == .scroll_down) state.scroll.scrollBy(3, state.visible_rows);
        },
        .resize => |sz| state.last_size = sz,
        .paste => |txt| try state.input.insertSlice(txt),
        .tick => {
            const dt_ms = app.deltaMs();
            _ = state.spinner_tween.advance(dt_ms);
        },
        else => {},
    }
    return true;
}
```

## Timed `.tick` Pacing & Custom Client Event Loops

`App.run()` drives animations consistently at `settings.fps` by automatically emitting `.tick` events both when polling times out and whenever continuous user input spans a full frame interval.

When your application integrates its own networking, game loop, or background worker queue, drive rendering explicitly instead of using `App.run()`:

```zig
while (app.isRunning()) {
    const dt_ms = app.advanceTimer();
    while (true) {
        const ev = try app.pollEvent(0); // non-blocking drain
        if (ev == .none) break;
        if (!try onEvent(&state, ev, &app)) break;
    }
    _ = state.spring.step(dt_ms);
    if (dirty_or_animating) try app.draw(&state, render);
    app.sleepFrame();
}
```

See [Animations, Effects & Custom Loops](/guides/animations-and-effects) for complete examples.

## Bracketed Paste, Kitty Keyboard & Mouse Protocols

- **Mouse Tracking**: Pass `.settings = .{ .mouse = true }` in `tui.init(alloc, .{ .settings = .{ .mouse = true } })`. Supports SGR (`CSI < ... M/m`) and fallback X10 mouse encoding alongside native Windows console mouse records.
- **Bracketed Paste**: Enabled by default so multi-line or escape-laden pastes arrive as a single `.paste` slice instead of triggering shortcuts (`TextInput` and `TextArea` consume `.paste` automatically).
- **Kitty Keyboard Protocol**: Supported alongside legacy VT/SS3/CSI escape sequences and Windows `ReadConsoleInputW` key records.
