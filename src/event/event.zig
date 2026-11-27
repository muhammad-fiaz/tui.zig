//! Unified terminal input and lifecycle event union.

const core_geom = @import("../core/geometry.zig");
const key_mod = @import("key.zig");
const mouse_mod = @import("mouse.zig");
const testing = @import("std").testing;

pub const Size = core_geom.Size;
pub const KeyEvent = key_mod.KeyEvent;
pub const KeyCode = key_mod.KeyCode;
pub const KeyModifiers = key_mod.KeyModifiers;
pub const KeyEventKind = key_mod.KeyEventKind;
pub const MouseEvent = mouse_mod.MouseEvent;
pub const MouseButton = mouse_mod.MouseButton;
pub const MouseEventKind = mouse_mod.MouseEventKind;

/// Normalized input or terminal state event returned by `readEvent` / `pollEvent`.
pub const Event = union(enum) {
    /// Keyboard press, repeat, or release event.
    key: KeyEvent,
    /// Mouse click, drag, move, or scroll wheel event.
    mouse: MouseEvent,
    /// Terminal viewport dimensions changed.
    resize: Size,
    /// Terminal window gained focus (when focus tracking enabled).
    focus_gained,
    /// Terminal window lost focus (when focus tracking enabled).
    focus_lost,
    /// Bracketed paste text payload. Borrowed from the parser's internal buffer;
    /// valid until the next event read/parse call.
    paste: []const u8,
    /// Periodic tick / no-input poll timeout.
    tick,
    /// No event currently available.
    none,

    /// True if this is a keyboard press/repeat for `KeyCode.escape`.
    pub fn isEscape(self: Event) bool {
        return self == .key and self.key.kind != .release and self.key.code == .escape;
    }

    /// True if this is a `Ctrl+C` keyboard press.
    pub fn isCtrlC(self: Event) bool {
        return self == .key and self.key.isCtrl('c');
    }

    /// True if this is a key press/repeat matching character `ch` without Ctrl/Alt.
    pub fn isChar(self: Event, ch: u21) bool {
        return self == .key and self.key.isChar(ch);
    }

    /// True if this is a resize event.
    pub fn isResize(self: Event) bool {
        return self == .resize;
    }

    /// True if this is any key press (excluding release events).
    pub fn isKeyPress(self: Event) bool {
        return self == .key and self.key.kind != .release;
    }
};

test "event convenience predicates" {
    const esc: Event = .{ .key = .{ .code = .escape } };
    try testing.expect(esc.isEscape());
    try testing.expect(esc.isKeyPress());

    const ctrl_c: Event = .{ .key = .{ .code = .{ .char = 'c' }, .modifiers = KeyModifiers.ctrl_only } };
    try testing.expect(ctrl_c.isCtrlC());

    const rsz: Event = .{ .resize = .{ .width = 120, .height = 40 } };
    try testing.expect(rsz.isResize());
}
