//! Terminal input events: keyboard, mouse, resize, focus, paste, and escape parsing.

const testing = @import("std").testing;

pub const key = @import("key.zig");
pub const mouse = @import("mouse.zig");
pub const event = @import("event.zig");
pub const parser = @import("parser.zig");

pub const KeyModifiers = key.KeyModifiers;
pub const KeyEventKind = key.KeyEventKind;
pub const MediaKey = key.MediaKey;
pub const ModifierKey = key.ModifierKey;
pub const KeyCode = key.KeyCode;
pub const KeyEvent = key.KeyEvent;

pub const MouseButton = mouse.MouseButton;
pub const MouseEventKind = mouse.MouseEventKind;
pub const MouseEvent = mouse.MouseEvent;

pub const Event = event.Event;
pub const EventParser = parser.EventParser;

test {
    testing.refAllDecls(@This());
    testing.refAllDecls(key);
    testing.refAllDecls(mouse);
    testing.refAllDecls(event);
    testing.refAllDecls(parser);
}
