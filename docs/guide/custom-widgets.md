# Custom Widgets

Create reusable components by implementing the widget interface.

## Widget Structure

A widget in TUI.zig is any struct that implements `render` and optionally `handleEvent`.

```zig
const std = @import("std");
const tui = @import("tui");

pub const MyWidget = struct {
    label: []const u8,
    clicked_count: usize = 0,

    pub fn init(label: []const u8) MyWidget {
        return .{ .label = label };
    }

    pub fn render(self: *MyWidget, ctx: *tui.RenderContext) void {
        var screen = ctx.getSubScreen();

        // Draw content
        screen.putString(self.label);
    }

    pub fn handleEvent(self: *MyWidget, event: tui.Event) tui.EventResult {
        // Handle input
        switch (event) {
            .key => |k| {
                if (k.key == .enter) {
                    self.clicked_count += 1;
                    return .needs_redraw;
                }
            },
            else => {},
        }
        return .ignored;
    }
};
```

## State Management

Widgets can hold internal state (like `clicked_count` above). If state changes affect the display, return `.needs_redraw` from `handleEvent`.

## Composition

Your custom widget can contain other widgets:

```zig
pub const CompositeWidget = struct {
    button: tui.Button,
    text: tui.Text,

    pub fn init() CompositeWidget {
        return .{
            .button = tui.Button.init("Click", onClick),
            .text = tui.Text.init("Status: Idle"),
        };
    }

    pub fn render(self: *CompositeWidget, ctx: *tui.RenderContext) void {
        // Delegate rendering
        var sub1 = ctx.screen.subRegion(0, 0, 10, 1);
        self.button.render(&sub1);

        var sub2 = ctx.screen.subRegion(0, 2, 20, 1);
        self.text.render(&sub2);
    }
};
```
