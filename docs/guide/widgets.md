# Widgets

TUI.zig provides a rich set of built-in widgets for building interactive terminal interfaces.

## Widget Basics

All widgets implement the same basic interface:

```zig
pub fn render(self: *Self, ctx: *RenderContext) void;
pub fn handleEvent(self: *Self, event: Event) EventResult;
```

## Built-in Widgets

### Text

Display styled text with alignment and wrapping:

```zig
const tui = @import("tui");

// Simple text
var text = tui.Text.init("Hello, World!");

// Styled text
var styled = tui.Text.init("Important!")
    .withStyle(tui.Style.default.setFg(tui.Color.red).bold())
    .withAlignment(.center);
```

### Button

Clickable buttons with hover and press states:

```zig
var button = tui.Button.init("Click Me!", null)
    .withOnClick(onButtonClick);

fn onButtonClick() void {
    // Button was clicked
}
```

### Input Field

Single-line text input with cursor:

```zig
var input = tui.InputField.init(allocator)
    .withPlaceholder("Enter your name...")
    .withMaxLength(50);

// Get the entered value
const value = input.getValue();
```

### Text Area

Multi-line text editing:

```zig
var textarea = tui.TextArea.init(allocator)
    .withLineNumbers()
    .withWordWrap();

// Set content
try textarea.setText("Line 1\nLine 2\nLine 3");
```

### Checkbox

Toggle checkboxes:

```zig
var checkbox = tui.Checkbox.init("Enable feature", null);

// Check state
if (checkbox.isChecked()) {
    // Feature is enabled
}
```

### Progress Bar

Visual progress indicators:

```zig
var progress = tui.ProgressBar.init()
    .withLabel("Loading...")
    .withShowPercentage(true);

// Update progress (0.0 - 1.0)
progress.setValue(0.75);
```

### Spinner

Animated loading indicators:

```zig
var spinner = tui.Spinner.initPreset(.dots)
    .withLabel("Processing...");

// In your render loop, update the animation
spinner.tick();
```

Available spinner presets:

- `.dots` - Braille dots animation
- `.line` - Line rotation (- \ | /)
- `.dots_scrolling` - Scrolling dots
- `.star` - Star animation
- `.box_bounce` - Bouncing box
- `.arrow` - Arrow rotation

### List View

Scrollable item lists with selection:

```zig
var list = tui.ListView.init(allocator, []const u8);

try list.addItem("Item 1");
try list.addItem("Item 2");
try list.addItem("Item 3");

// Get selected item
if (list.getSelectedItem()) |item| {
    // Process selected item
}
```

### Table

Data tables with columns:

```zig
var table = tui.Table.init(allocator);

try table.addColumn("Name", 20);
try table.addColumn("Email", 30);
try table.addColumn("Role", 15);

try table.addRow(.{ "John Doe", "john@example.com", "Admin" });
try table.addRow(.{ "Jane Smith", "jane@example.com", "User" });
```

### Tabs

Tabbed navigation:

```zig
var tabs = tui.Tabs.init(allocator);

try tabs.addTab("Home", &home_widget);
try tabs.addTab("Settings", &settings_widget);
try tabs.addTab("Help", &help_widget);
```

### Modal

Dialog overlays:

```zig
var modal = tui.Modal.init(allocator)
    .withTitle("Confirm Action")
    .withContent(&confirm_widget)
    .withButtons(.{ "OK", "Cancel" });

modal.show();
```

### Accordion

Collapsible content sections with single or multiple expansion:

```zig
var items = [_]tui.AccordionItem{
    .{ .title = "Section 1", .content = "Content for section 1" },
    .{ .title = "Section 2", .content = "Content for section 2" },
};
var accordion = tui.Accordion.init(&items)
    .withMode(.single);
```

### Alert

Status messages and notifications:

```zig
var alert = tui.Alert.init("Warning", "Disk space is low");
alert.show();
```

### AlertDialog

Confirmation dialogs with action buttons:

```zig
var dialog = tui.AlertDialog.init("Delete File", "Are you sure?");
dialog.on_confirm = onConfirm;
dialog.on_cancel = onCancel;
```

### Badge

Labels, tags, and status indicators:

```zig
var badge = tui.Badge.init("New")
    .withVariant(.success)
    .withSize(.small);
```

### Breadcrumb

Navigation breadcrumb trail:

```zig
const items = [_]tui.BreadcrumbItem{
    .{ .label = "Home" },
    .{ .label = "Products" },
    .{ .label = "Electronics" },
};
var breadcrumb = tui.Breadcrumb.init(&items);
```

### Card

Grouped content with optional borders and headers:

```zig
var card = tui.Card.init("Card content here")
    .withTitle("My Card")
    .withFooter("Card footer");
```

### Grid

Layout grid for arranging widgets:

```zig
var grid = tui.Grid.init(3, 2); // 3 rows, 2 columns
```

### Image

Image display with Kitty, iTerm2, Sixel, and ASCII protocol support:

```zig
var img = tui.Image.init(data, 80, 24)
    .withProtocol(.ascii);
```

### Menu

Dropdown and context menus:

```zig
const items = [_]tui.MenuItem{
    .{ .label = "Open" },
    .{ .label = "Save" },
    .{ .separator = true },
    .{ .label = "Exit" },
};
var menu = tui.Menu.init(&items);
```

### Navbar

Top navigation bar:

```zig
const items = [_]tui.NavItem{
    .{ .label = "Home" },
    .{ .label = "About" },
    .{ .label = "Contact" },
};
var navbar = tui.Navbar.init(&items);
```

### Pagination

Page navigation controls:

```zig
var pagination = tui.Pagination.init(10) // 10 pages
    .withOnChange(onPageChange);
```

### Radio

Radio button groups for single selection:

```zig
const options = [_]tui.RadioOption{
    .{ .label = "Option A", .value = 0 },
    .{ .label = "Option B", .value = 1 },
    .{ .label = "Option C", .value = 2 },
};
var radio = tui.RadioGroup.init(&options)
    .withOnChange(onRadioChange);
```

### Scroll View

Scrollable content container:

```zig
var scroll = tui.ScrollView.init(&content_widget);
```

### Separator

Visual content dividers:

```zig
var sep = tui.Separator.init()
    .withOrientation(.horizontal)
    .withStyle(.double);
```

### Sidebar

Side navigation panel:

```zig
const items = [_]tui.SidebarItem{
    .{ .label = "Dashboard" },
    .{ .label = "Settings" },
    .{ .label = "Profile" },
};
var sidebar = tui.Sidebar.init(&items);
```

### Skeleton

Loading placeholders with shimmer animation:

```zig
var skeleton = tui.Skeleton.init(.rectangle)
    .withSize(30, 5);
```

### Slider

Numeric slider input:

```zig
var slider = tui.Slider.init(0.0, 100.0)
    .withValue(50.0)
    .withStep(5.0);
```

### Split View

Side-by-side content panels:

```zig
var split = tui.SplitView.init(&left_panel, &right_panel)
    .withDirection(.horizontal)
    .withRatio(0.3);
```

### Statusbar

Bottom status bar:

```zig
const items = [_]tui.StatusItem{
    .{ .text = "Ready", .alignment = .left },
    .{ .text = "Ln 1, Col 1", .alignment = .right },
};
var statusbar = tui.Statusbar.init(&items);
```

### Switch

Toggle switch for boolean settings:

```zig
var switch = tui.Switch.init("Dark mode");
```

### Toast

Temporary notification popups:

```zig
var toast = tui.Toast.init("File saved successfully");
var manager = tui.ToastManager.init(allocator);
try manager.show(toast);
```

### Tooltip

Contextual help on hover:

```zig
var tooltip = tui.Tooltip.init("Click to save")
    .withPosition(.bottom);
tooltip.show();
```

### Tree

Hierarchical tree view:

```zig
var nodes = [_]tui.TreeNode{
    .{ .label = "Root" },
    .{ .label = "Child 1" },
    .{ .label = "Child 2" },
};
var tree = tui.TreeView.init(&nodes);
```

### Border

Border drawing utilities:

```zig
var border = tui.Border.init()
    .withStyle(.double)
    .withTitle("Panel");
```

## Creating Custom Widgets

You can create your own widgets by implementing the required interface:

```zig
const MyWidget = struct {
    // Your state
    value: i32 = 0,

    pub fn render(self: *MyWidget, ctx: *tui.RenderContext) void {
        var screen = ctx.getSubScreen();
        screen.setStyle(tui.Style.default.setFg(tui.Color.green));
        screen.moveCursor(0, 0);

        var buf: [32]u8 = undefined;
        const text = std.fmt.bufPrint(&buf, "Value: {d}", .{self.value}) catch "?";
        screen.putString(text);
    }

    pub fn handleEvent(self: *MyWidget, event: tui.Event) tui.EventResult {
        switch (event) {
            .key => |k| switch (k.key) {
                .up => { self.value += 1; return .needs_redraw; },
                .down => { self.value -= 1; return .needs_redraw; },
                else => {},
            },
            else => {},
        }
        return .ignored;
    }
};
```

See the [Custom Widgets](/guide/custom-widgets) guide for more details.
