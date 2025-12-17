// Radio button widget for mutually exclusive selections.
// Provides single-choice selection within a group of options.

const std = @import("std");
const widget = @import("widget.zig");
const Style = @import("../style/style.zig").Style;
const Color = @import("../style/color.zig").Color;
const Event = @import("../event/events.zig").Event;

pub const RadioOption = struct {
    label: []const u8,
    value: usize,
};

pub const RadioGroup = struct {
    options: []const RadioOption,
    selected: usize = 0,
    base: widget.StatefulWidget = .{},
    style: Style = Style.default,
    on_change: ?*const fn (usize) void = null,

    pub fn init(options: []const RadioOption) RadioGroup {
        return .{ .options = options };
    }

    pub fn withSelected(self: RadioGroup, index: usize) RadioGroup {
        var result = self;
        result.selected = index;
        return result;
    }

    pub fn withOnChange(self: RadioGroup, callback: *const fn (usize) void) RadioGroup {
        var result = self;
        result.on_change = callback;
        return result;
    }

    pub fn render(self: *RadioGroup, ctx: *widget.RenderContext) void {
        var sub = ctx.getSubScreen();
        
        for (self.options, 0..) |option, i| {
            const y: u16 = @intCast(i);
            if (y >= sub.height) break;

            sub.moveCursor(0, y);
            
            if (i == self.selected) {
                sub.setStyle(self.style.setFg(Color.green).bold());
                sub.putString("(•) ");
            } else {
                sub.setStyle(self.style.setFg(Color.fromRGB(150, 150, 150)));
                sub.putString("( ) ");
            }
            
            sub.setStyle(self.style);
            sub.putString(option.label);
        }
    }

    pub fn handleEvent(self: *RadioGroup, event: Event) widget.EventResult {
        switch (event) {
            .key => |k| {
                switch (k.key) {
                    .up => {
                        if (self.selected > 0) {
                            self.selected -= 1;
                            if (self.on_change) |cb| cb(self.selected);
                            return .needs_redraw;
                        }
                    },
                    .down => {
                        if (self.selected + 1 < self.options.len) {
                            self.selected += 1;
                            if (self.on_change) |cb| cb(self.selected);
                            return .needs_redraw;
                        }
                    },
                    .char => |c| {
                        if (c >= '1' and c <= '9') {
                            const idx = c - '1';
                            if (idx < self.options.len) {
                                self.selected = idx;
                                if (self.on_change) |cb| cb(self.selected);
                                return .needs_redraw;
                            }
                        }
                    },
                    else => {},
                }
            },
            else => {},
        }
        return .ignored;
    }

    pub fn isFocusable(self: *RadioGroup) bool {
        _ = self;
        return true;
    }

    pub fn setFocus(self: *RadioGroup, focused: bool) void {
        self.base.state.focused = focused;
    }
};
