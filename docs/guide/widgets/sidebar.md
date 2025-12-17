# Sidebar

Side navigation panel with collapsible support.

## Basic Usage

```zig
const items = [_]tui.sidebar.SidebarItem{
    .{ .label = "Dashboard", .icon = "📊" },
    .{ .label = "Files", .icon = "📁" },
    .{ .label = "Settings", .icon = "⚙️" },
};

var sidebar = tui.Sidebar.init(&items)
    .withPosition(.left)
    .withWidth(20);
```

## Features

- Left or right positioning
- Collapsible mode
- Icon support
- Keyboard navigation
- Custom width

## API

```zig
pub fn init(items: []const SidebarItem) Sidebar
pub fn withPosition(self: Sidebar, position: SidebarPosition) Sidebar
pub fn withWidth(self: Sidebar, width: u16) Sidebar
pub fn toggle(self: *Sidebar) void

pub const SidebarPosition = enum { left, right };
```

## Example

```zig
const AppWithSidebar = struct {
    sidebar: tui.Sidebar,
    items: [4]tui.sidebar.SidebarItem,

    pub fn init() AppWithSidebar {
        var app = AppWithSidebar{
            .items = [_]tui.sidebar.SidebarItem{
                .{ .label = "Home", .icon = "🏠" },
                .{ .label = "Projects", .icon = "📂" },
                .{ .label = "Tasks", .icon = "✓" },
                .{ .label = "Settings", .icon = "⚙️" },
            },
            .sidebar = undefined,
        };
        app.sidebar = tui.Sidebar.init(&app.items).withWidth(25);
        return app;
    }

    pub fn render(self: *AppWithSidebar, ctx: *tui.RenderContext) void {
        const width = if (self.sidebar.collapsed) 3 else self.sidebar.width;
        const rect = tui.Rect{ 
            .x = 0, 
            .y = 0, 
            .width = width, 
            .height = ctx.bounds.height 
        };
        var sidebar_ctx = ctx.child(rect);
        self.sidebar.render(&sidebar_ctx);
    }
};
```

## Keyboard Controls

- `↑` / `↓` - Navigate items
- `Enter` - Select item
- `Tab` - Toggle collapse
