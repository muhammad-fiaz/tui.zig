//! Mouse event types, buttons, actions, and hit-testing helpers.

const geom = @import("../core/geometry.zig");
const key_mod = @import("key.zig");
const testing = @import("std").testing;

pub const KeyModifiers = key_mod.KeyModifiers;
pub const Rect = geom.Rect;
pub const Position = geom.Position;

/// Mouse button associated with a press, release, drag, or scroll event.
pub const MouseButton = enum {
    left,
    right,
    middle,
    none,
    extra1,
    extra2,
};

/// Type of mouse interaction.
pub const MouseEventKind = enum {
    down,
    up,
    drag,
    moved,
    scroll_up,
    scroll_down,
    scroll_left,
    scroll_right,
};

/// Normalized terminal mouse event in 0-based cell coordinates.
pub const MouseEvent = struct {
    kind: MouseEventKind,
    button: MouseButton = .none,
    x: u16,
    y: u16,
    modifiers: KeyModifiers = .none,

    pub fn position(self: MouseEvent) Position {
        return .{ .x = self.x, .y = self.y };
    }

    /// True if this mouse event falls inside `rect`.
    pub fn isInside(self: MouseEvent, rect: Rect) bool {
        return rect.containsXY(self.x, self.y);
    }

    /// True if this is a left mouse button press inside `rect`.
    pub fn isLeftClickInside(self: MouseEvent, rect: Rect) bool {
        return self.kind == .down and self.button == .left and self.isInside(rect);
    }
};

test "mouse hit testing" {
    const r = Rect.init(10, 5, 10, 3);
    const ev: MouseEvent = .{ .kind = .down, .button = .left, .x = 12, .y = 6 };
    try testing.expect(ev.isInside(r));
    try testing.expect(ev.isLeftClickInside(r));
    try testing.expect(!ev.isInside(Rect.init(0, 0, 5, 5)));
}
