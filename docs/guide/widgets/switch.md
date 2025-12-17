# Switch

Modern toggle widget for boolean on/off states.

## Basic Usage

```zig
var switch_widget = tui.Switch.init("Enable notifications")
    .withEnabled(false)
    .withOnChange(handleToggle);
```

## Features

- Visual on/off indicator
- Optional label
- Change callbacks
- Keyboard control
- Custom styling

## API

```zig
pub fn init(label: []const u8) Switch
pub fn withEnabled(self: Switch, enabled: bool) Switch
pub fn withOnChange(self: Switch, callback: *const fn (bool) void) Switch
pub fn toggle(self: *Switch) void
pub fn setEnabled(self: *Switch, enabled: bool) void
```

## Example

```zig
const Settings = struct {
    notifications: tui.Switch,
    dark_mode: tui.Switch,

    pub fn init() Settings {
        return .{
            .notifications = tui.Switch.init("Notifications").withEnabled(true),
            .dark_mode = tui.Switch.init("Dark Mode").withEnabled(false),
        };
    }

    pub fn render(self: *Settings, ctx: *tui.RenderContext) void {
        var screen = ctx.getSubScreen();
        
        screen.moveCursor(2, 2);
        screen.putString("Settings:");
        
        const notif_rect = tui.Rect{ .x = 4, .y = 4, .width = 30, .height = 1 };
        var notif_ctx = ctx.child(notif_rect);
        self.notifications.render(&notif_ctx);
        
        const dark_rect = tui.Rect{ .x = 4, .y = 6, .width = 30, .height = 1 };
        var dark_ctx = ctx.child(dark_rect);
        self.dark_mode.render(&dark_ctx);
    }
};
```

## Keyboard Controls

- `Space` / `Enter` - Toggle state
