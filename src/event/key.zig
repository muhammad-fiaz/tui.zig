//! Keyboard event types, key codes, modifiers, and matching helpers.

const std = @import("std");
const testing = std.testing;

/// Modifier keys held during a keyboard or mouse event.
pub const KeyModifiers = packed struct(u8) {
    shift: bool = false,
    ctrl: bool = false,
    alt: bool = false,
    super: bool = false,
    hyper: bool = false,
    meta: bool = false,
    _padding: u2 = 0,

    pub const none: KeyModifiers = .{};
    pub const shift_only: KeyModifiers = .{ .shift = true };
    pub const ctrl_only: KeyModifiers = .{ .ctrl = true };
    pub const alt_only: KeyModifiers = .{ .alt = true };

    pub fn eql(a: KeyModifiers, b: KeyModifiers) bool {
        return @as(u8, @bitCast(a)) == @as(u8, @bitCast(b));
    }

    pub fn any(self: KeyModifiers) bool {
        return @as(u8, @bitCast(self)) != 0;
    }
};

/// Keyboard transition state (requires enhanced keyboard protocol for repeat/release on POSIX;
/// supported natively on Windows Console).
pub const KeyEventKind = enum {
    press,
    repeat,
    release,
};

/// Media control keys.
pub const MediaKey = enum {
    play,
    pause,
    play_pause,
    stop,
    fast_forward,
    rewind,
    next,
    previous,
    volume_up,
    volume_down,
    mute,
};

/// Standalone modifier key codes (when reported directly).
pub const ModifierKey = enum {
    left_shift,
    right_shift,
    left_ctrl,
    right_ctrl,
    left_alt,
    right_alt,
    left_super,
    right_super,
};

/// Normalized keyboard key identifier.
pub const KeyCode = union(enum) {
    /// Unicode scalar character (`'a'`, `'A'`, `'€'`, `'あ'`, etc.).
    char: u21,
    enter,
    tab,
    back_tab,
    backspace,
    delete,
    insert,
    escape,
    up,
    down,
    left,
    right,
    home,
    end,
    page_up,
    page_down,
    /// Function key `F1..F24`.
    f: u8,
    caps_lock,
    scroll_lock,
    num_lock,
    print_screen,
    pause,
    menu,
    media: MediaKey,
    modifier: ModifierKey,
    null_key,

    pub fn eql(a: KeyCode, b: KeyCode) bool {
        return std.meta.eql(a, b);
    }
};

/// Complete keyboard event emitted by terminal backends.
pub const KeyEvent = struct {
    code: KeyCode,
    modifiers: KeyModifiers = .none,
    kind: KeyEventKind = .press,

    /// True when this is a key press (or repeat) matching ASCII/Unicode scalar `ch` with no ctrl/alt.
    pub fn isChar(self: KeyEvent, ch: u21) bool {
        return self.kind != .release and
            self.code == .char and
            self.code.char == ch and
            !self.modifiers.ctrl and
            !self.modifiers.alt;
    }

    /// True when this is a press/repeat matching `code` and exact `mods`.
    pub fn matches(self: KeyEvent, code: KeyCode, mods: KeyModifiers) bool {
        return self.kind != .release and self.code.eql(code) and self.modifiers.eql(mods);
    }

    /// True when Ctrl+`ch` (case-insensitive for ASCII letters) is pressed.
    pub fn isCtrl(self: KeyEvent, ch: u8) bool {
        if (self.kind == .release or !self.modifiers.ctrl) return false;
        if (self.code != .char) return false;
        const cp = self.code.char;
        if (cp > 127) return false;
        return std.ascii.toLower(@intCast(cp)) == std.ascii.toLower(ch);
    }
};

test "key event matching helpers" {
    const k1: KeyEvent = .{ .code = .{ .char = 'c' }, .modifiers = KeyModifiers.ctrl_only };
    try testing.expect(k1.isCtrl('c'));
    try testing.expect(k1.isCtrl('C'));
    try testing.expect(!k1.isChar('c'));

    const k2: KeyEvent = .{ .code = .{ .char = 'q' } };
    try testing.expect(k2.isChar('q'));
}
