# Navbar

Top navigation bar for application-level navigation.

## Basic Usage

```zig
const items = [_]tui.navbar.NavItem{
    .{ .label = "Home", .icon = "🏠" },
    .{ .label = "Settings", .icon = "⚙️" },
    .{ .label = "Help", .icon = "❓" },
};

var navbar = tui.Navbar.init(&items)
    .withTitle("My Application");
```

## Features

- Icon support
- Title display
- Keyboard navigation
- Click callbacks
- Custom styling

## API

```zig
pub fn init(items: []const NavItem) Navbar
pub fn withTitle(self: Navbar, title: []const u8) Navbar

pub const NavItem = struct {
    label: []const u8,
    icon: ?[]const u8 = null,
    on_click: ?*const fn () void = null,
};
```

## Example

```zig
const AppLayout = struct {
    navbar: tui.Navbar,
    items: [3]tui.navbar.NavItem,

    pub fn init() AppLayout {
        var layout = AppLayout{
            .items = [_]tui.navbar.NavItem{
                .{ .label = "Dashboard", .icon = "📊", .on_click = &onDashboard },
                .{ .label = "Files", .icon = "📁", .on_click = &onFiles },
                .{ .label = "Settings", .icon = "⚙️", .on_click = &onSettings },
            },
            .navbar = undefined,
        };
        layout.navbar = tui.Navbar.init(&layout.items).withTitle("File Manager");
        return layout;
    }

    fn onDashboard() void {}
    fn onFiles() void {}
    fn onSettings() void {}

    pub fn render(self: *AppLayout, ctx: *tui.RenderContext) void {
        const rect = tui.Rect{ .x = 0, .y = 0, .width = ctx.bounds.width, .height = 1 };
        var nav_ctx = ctx.child(rect);
        self.navbar.render(&nav_ctx);
    }
};
```

## Keyboard Controls

- `←` / `→` - Navigate items
- `Enter` - Select item
