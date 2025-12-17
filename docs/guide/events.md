# Events

TUI.zig uses an event-driven architecture to handle user input.

## Event Types

The top-level `Event` union covers all input types:

```zig
const Event = union(enum) {
    key: KeyEvent,
    mouse: MouseEvent,
    resize: ResizeEvent,
    focus_in,
    focus_out,
    paste: PasteEvent,
};
```

## Keyboard Events

Keyboard events include the key pressed and modifiers (Ctrl, Alt, Shift).

```zig
pub fn handleEvent(self: *MyWidget, event: Event) EventResult {
    switch (event) {
        .key => |k| {
            // Check modifiers
            if (k.modifiers.ctrl) {
                if (k.key == .char and k.key.char == 'c') {
                    return .quit; // or custom quit logic
                }
            }

            // Check specific keys
            switch (k.key) {
                .enter => self.submit(),
                .up => self.moveSelection(-1),
                .down => self.moveSelection(1),
                .char => |c| self.addChar(c),
                else => {},
            }
        },
        else => {},
    }
    return .ignored;
}
```

### Key Types

Keys can be characters or special keys:

- `.char: u21` - Unicode character
- `.enter`, `.tab`, `.backspace`, `.escape`, `.space`
- `.up`, `.down`, `.left`, `.right`
- `.home`, `.end`, `.page_up`, `.page_down`
- `.insert`, `.delete`
- `.f: u8` - F1-F12 keys

## Mouse Events

Mouse events track movement and button states.

```zig
const MouseEvent = struct {
    x: u16,
    y: u16,
    button: MouseButton,
    action: MouseAction,
    modifiers: Modifiers,
};

const MouseButton = enum { left, middle, right, none };
const MouseAction = enum { press, release, drag, move, scroll_up, scroll_down };
```

Example handling:

```zig
.mouse => |m| {
    if (m.action == .press and m.button == .left) {
        if (self.contains(m.x, m.y)) {
            self.clicked();
            return .consumed;
        }
    }
}
```

## Event Propagation

Events are typically dispatched from the root widget down to child widgets. A widget should return an `EventResult`:

- `.ignored` - The event was not handled; propagate to next handler.
- `.consumed` - The event was handled; stop propagation.
- `.needs_redraw` - The event was handled and changed state; request a screen update.

## Focus Management

Widgets can receive focus events (`.focus_in`, `.focus_out`). A container widget typically manages which child has focus and dispatches key events only to the focused child.
