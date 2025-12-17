# Radio Group

Mutually exclusive selection widget for choosing one option from multiple choices.

## Basic Usage

```zig
const options = [_]tui.radio.RadioOption{
    .{ .label = "Small", .value = 0 },
    .{ .label = "Medium", .value = 1 },
    .{ .label = "Large", .value = 2 },
};

var radio = tui.RadioGroup.init(&options)
    .withSelected(1);
```

## Features

- Single selection from multiple options
- Keyboard navigation (↑/↓)
- Number key shortcuts (1-9)
- Custom styling
- Change callbacks

## API

### Creation

```zig
pub fn init(options: []const RadioOption) RadioGroup
pub fn withSelected(self: RadioGroup, index: usize) RadioGroup
pub fn withOnChange(self: RadioGroup, callback: *const fn (usize) void) RadioGroup
```

### RadioOption

```zig
pub const RadioOption = struct {
    label: []const u8,
    value: usize,
};
```

## Example

```zig
const SizeSelector = struct {
    radio: tui.RadioGroup,
    options: [3]tui.radio.RadioOption,

    pub fn init() SizeSelector {
        var selector = SizeSelector{
            .options = [_]tui.radio.RadioOption{
                .{ .label = "Small (S)", .value = 0 },
                .{ .label = "Medium (M)", .value = 1 },
                .{ .label = "Large (L)", .value = 2 },
            },
            .radio = undefined,
        };
        selector.radio = tui.RadioGroup.init(&selector.options);
        return selector;
    }

    pub fn render(self: *SizeSelector, ctx: *tui.RenderContext) void {
        var screen = ctx.getSubScreen();
        
        screen.moveCursor(2, 2);
        screen.putString("Select size:");
        
        const rect = tui.Rect{ .x = 2, .y = 4, .width = 20, .height = 5 };
        var radio_ctx = ctx.child(rect);
        self.radio.render(&radio_ctx);
    }

    pub fn handleEvent(self: *SizeSelector, event: tui.Event) tui.EventResult {
        return self.radio.handleEvent(event);
    }
};
```

## Keyboard Controls

- `↑` / `k` - Previous option
- `↓` / `j` - Next option
- `1-9` - Quick select by number
- `Enter` / `Space` - Confirm selection
