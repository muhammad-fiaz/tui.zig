# Badge Widget

## Overview

The `Badge` widget displays small labels, tags, or status indicators with various colors and sizes. It's commonly used for highlighting information, showing status, displaying counts, or categorizing content. Badges are compact, visually distinct elements that draw attention to important information.

## Properties

- `text`: The text content displayed in the badge
- `variant`: `BadgeVariant` enum controlling the color scheme:
  - `.default`: Neutral gray color scheme
  - `.primary`: Blue color scheme for primary actions
  - `.secondary`: Light gray color scheme for secondary information
  - `.success`: Green color scheme for positive states
  - `.warning`: Yellow color scheme for cautionary information
  - `.error_badge`: Red color scheme for error states
  - `.info`: Cyan color scheme for informational content
- `size`: `BadgeSize` enum controlling padding and visual weight:
  - `.small`: Minimal padding, compact appearance
  - `.medium`: Standard padding, balanced appearance
  - `.large`: Extra padding, prominent appearance

## Methods

- `init(text: []const u8)`: Creates a new badge with the specified text
- `withVariant(variant: BadgeVariant)`: Sets the badge's color variant
- `withSize(size: BadgeSize)`: Sets the badge's size/padding
- `render(ctx: *RenderContext)`: Renders the badge with appropriate styling

## Events

None - the badge is a static display widget that doesn't handle user input.

## Usage Examples

### Basic Status Badges

```zig
const tui = @import("tui");
const Badge = tui.widgets.Badge;

var activeBadge = Badge.init("Active").withVariant(.success);
var inactiveBadge = Badge.init("Inactive").withVariant(.secondary);
var errorBadge = Badge.init("Error").withVariant(.error_badge);
```

### Size Variations

```zig
var smallBadge = Badge.init("New").withSize(.small);
var mediumBadge = Badge.init("Updated").withSize(.medium);
var largeBadge = Badge.init("Important").withSize(.large);
```

### Notification Counters

```zig
fn createNotificationBadge(count: usize) Badge {
    var buf: [16]u8 = undefined;
    const text = std.fmt.bufPrint(&buf, "{}", .{count}) catch "99+";
    
    return Badge.init(text)
        .withVariant(if (count > 0) .primary else .secondary)
        .withSize(.small);
}

var notificationBadge = createNotificationBadge(5);
```

### Status Indicators

```zig
const StatusBadge = struct {
    status: enum { online, offline, busy, away },
    
    pub fn toBadge(self: StatusBadge) Badge {
        return switch (self.status) {
            .online => Badge.init("Online").withVariant(.success),
            .offline => Badge.init("Offline").withVariant(.secondary),
            .busy => Badge.init("Busy").withVariant(.warning),
            .away => Badge.init("Away").withVariant(.info),
        };
    }
};

var userStatus = StatusBadge{ .status = .online };
var statusBadge = userStatus.toBadge();
```

### Priority Levels

```zig
const Priority = enum {
    low,
    medium,
    high,
    critical,
    
    pub fn toBadge(self: Priority) Badge {
        return switch (self) {
            .low => Badge.init("Low").withVariant(.secondary).withSize(.small),
            .medium => Badge.init("Medium").withVariant(.info),
            .high => Badge.init("High").withVariant(.warning),
            .critical => Badge.init("Critical").withVariant(.error_badge).withSize(.large),
        };
    }
};

var taskPriority = Priority.high;
var priorityBadge = taskPriority.toBadge();
```

### Badge Collection/List

```zig
const BadgeList = struct {
    badges: std.ArrayList(Badge),
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) BadgeList {
        return .{
            .badges = std.ArrayList(Badge).init(allocator),
            .allocator = allocator,
        };
    }
    
    pub fn addTag(self: *BadgeList, tag: []const u8) !void {
        try self.badges.append(Badge.init(tag).withVariant(.default).withSize(.small));
    }
    
    pub fn render(self: *BadgeList, ctx: *RenderContext) void {
        var x: u16 = 0;
        for (self.badges.items) |*badge| {
            var badge_ctx = ctx.child(Rect.init(x, 0, 20, 1)); // Fixed width per badge
            badge.render(&badge_ctx);
            x += 22; // Space between badges
        }
    }
};

// Usage
var tags = BadgeList.init(allocator);
try tags.addTag("React");
try tags.addTag("TypeScript");
try tags.addTag("Frontend");
```

### Dynamic Badge Updates

```zig
const CounterBadge = struct {
    count: usize,
    badge: Badge,
    
    pub fn init() CounterBadge {
        return .{
            .count = 0,
            .badge = Badge.init("0").withVariant(.primary).withSize(.small),
        };
    }
    
    pub fn increment(self: *CounterBadge) void {
        self.count += 1;
        self.updateText();
    }
    
    pub fn decrement(self: *CounterBadge) void {
        if (self.count > 0) {
            self.count -= 1;
            self.updateText();
        }
    }
    
    fn updateText(self: *CounterBadge) void {
        var buf: [16]u8 = undefined;
        const text = std.fmt.bufPrint(&buf, "{}", .{self.count}) catch "99+";
        self.badge = Badge.init(text).withVariant(.primary).withSize(.small);
    }
};

var counter = CounterBadge.init();
counter.increment(); // Badge now shows "1"
```

## Styling Guidelines

- Use consistent variants for similar types of information
- Choose appropriate sizes based on context and importance
- Consider color accessibility - don't rely solely on color for meaning
- Keep text concise - badges work best with short labels
- Use standard variants for common patterns (success for positive, error for negative)

## Common Use Cases

- **Status indicators**: Online/offline, active/inactive states
- **Notification counters**: Unread messages, pending tasks
- **Priority levels**: Low, medium, high, critical
- **Tags and categories**: Content classification, feature flags
- **Progress indicators**: Step completion, workflow states
- **User roles**: Admin, moderator, member designations