//! Event types and definitions for TUI.zig

const std = @import("std");
const input = @import("input.zig");

pub const Key = input.Key;
pub const Mouse = input.Mouse;

/// Event type that can be dispatched through the event loop
pub const Event = union(enum) {
    /// Keyboard input
    key: KeyEvent,

    /// Mouse input
    mouse: MouseEvent,

    /// Terminal resize
    resize: ResizeEvent,

    /// Focus gained
    focus_gained,

    /// Focus lost
    focus_lost,

    /// Paste event
    paste: PasteEvent,

    /// Tick event (for animation/timers)
    tick: TickEvent,

    /// User-defined event
    user: UserEvent,

    /// Quit request
    quit,
};

/// Keyboard event data
pub const KeyEvent = struct {
    /// The key that was pressed
    key: Key,

    /// Modifier keys held during the press
    modifiers: Modifiers = .{},

    /// Raw bytes if available
    raw: ?[]const u8 = null,
};

/// Key modifiers
pub const Modifiers = packed struct {
    shift: bool = false,
    alt: bool = false,
    ctrl: bool = false,
    super: bool = false,
    hyper: bool = false,
    meta: bool = false,
    _padding: u2 = 0,

    /// Check if any modifier is pressed
    pub fn any(self: Modifiers) bool {
        return self.shift or self.alt or self.ctrl or self.super or self.hyper or self.meta;
    }

    /// Check if no modifiers are pressed
    pub fn none(self: Modifiers) bool {
        return !self.any();
    }
};

/// Mouse event data
pub const MouseEvent = struct {
    /// Mouse action type
    kind: MouseKind,

    /// X coordinate (0-indexed)
    x: u16,

    /// Y coordinate (0-indexed)
    y: u16,

    /// Button involved (if applicable)
    button: MouseButton = .none,

    /// Modifiers held during the event
    modifiers: Modifiers = .{},
};

/// Type of mouse action
pub const MouseKind = enum {
    press,
    release,
    move,
    drag,
    scroll_up,
    scroll_down,
    scroll_left,
    scroll_right,
};

/// Mouse buttons
pub const MouseButton = enum {
    none,
    left,
    middle,
    right,
    wheel_up,
    wheel_down,
    button4,
    button5,
};

/// Resize event data
pub const ResizeEvent = struct {
    /// New terminal width in columns
    cols: u16,

    /// New terminal height in rows
    rows: u16,
};

/// Paste event data
pub const PasteEvent = struct {
    /// Pasted text content
    content: []const u8,
};

/// Tick event for animation and timers
pub const TickEvent = struct {
    /// Tick number
    tick: u64,

    /// Time since last tick in nanoseconds
    delta_ns: u64,

    /// Total elapsed time in nanoseconds
    elapsed_ns: u64,
};

/// User-defined event
pub const UserEvent = struct {
    /// Event type identifier
    type_id: u32,

    /// Event data (pointer to user-defined struct)
    data: ?*anyopaque,
};

/// Event queue for buffering events
pub const EventQueue = struct {
    allocator: std.mem.Allocator,
    events: std.ArrayListUnmanaged(Event),
    max_size: usize,

    pub fn init(allocator: std.mem.Allocator, max_size: usize) EventQueue {
        return .{
            .allocator = allocator,
            .events = .{},
            .max_size = max_size,
        };
    }

    pub fn deinit(self: *EventQueue) void {
        self.events.deinit(self.allocator);
    }

    /// Push an event to the queue
    pub fn push(self: *EventQueue, event: Event) !void {
        if (self.events.items.len >= self.max_size) {
            // Drop oldest event
            _ = self.events.orderedRemove(0);
        }
        try self.events.append(self.allocator, event);
    }

    /// Pop an event from the queue
    pub fn pop(self: *EventQueue) ?Event {
        if (self.events.items.len == 0) return null;
        return self.events.orderedRemove(0);
    }

    /// Peek at the next event without removing it
    pub fn peek(self: *EventQueue) ?Event {
        if (self.events.items.len == 0) return null;
        return self.events.items[0];
    }

    /// Check if queue is empty
    pub fn isEmpty(self: *EventQueue) bool {
        return self.events.items.len == 0;
    }

    /// Get number of events in queue
    pub fn len(self: *EventQueue) usize {
        return self.events.items.len;
    }

    /// Clear all events
    pub fn clear(self: *EventQueue) void {
        self.events.clearRetainingCapacity();
    }
};

/// Event handler callback type
pub const EventHandler = *const fn (Event) bool;

/// Event filter for selective event processing
pub const EventFilter = struct {
    /// Filter keyboard events
    keys: bool = true,

    /// Filter mouse events
    mouse: bool = true,

    /// Filter resize events
    resize: bool = true,

    /// Filter focus events
    focus: bool = true,

    /// Filter paste events
    paste: bool = true,

    /// Filter tick events
    tick: bool = true,

    /// Check if an event passes the filter
    pub fn passes(self: EventFilter, event: Event) bool {
        return switch (event) {
            .key => self.keys,
            .mouse => self.mouse,
            .resize => self.resize,
            .focus_gained, .focus_lost => self.focus,
            .paste => self.paste,
            .tick => self.tick,
            .user, .quit => true,
        };
    }
};

test "event queue" {
    const allocator = std.testing.allocator;
    var queue = EventQueue.init(allocator, 100);
    defer queue.deinit();

    try queue.push(.{ .key = .{ .key = .{ .char = 'a' } } });
    try queue.push(.{ .key = .{ .key = .{ .char = 'b' } } });

    try std.testing.expectEqual(@as(usize, 2), queue.len());
    try std.testing.expect(!queue.isEmpty());

    const event = queue.pop();
    try std.testing.expect(event != null);

    try std.testing.expectEqual(@as(usize, 1), queue.len());
}

test "modifiers" {
    const mods = Modifiers{ .ctrl = true, .shift = true };
    try std.testing.expect(mods.any());
    try std.testing.expect(!mods.none());

    const no_mods = Modifiers{};
    try std.testing.expect(!no_mods.any());
    try std.testing.expect(no_mods.none());
}
