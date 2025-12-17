# Slider

Numeric value selection widget with visual feedback.

## Basic Usage

```zig
var slider = tui.Slider.init(0.0, 100.0)
    .withValue(50.0)
    .withStep(1.0)
    .withOrientation(.horizontal);
```

## Features

- Horizontal and vertical orientations
- Customizable range and step
- Visual progress indicator
- Keyboard control
- Change callbacks

## API

```zig
pub fn init(min: f32, max: f32) Slider
pub fn withValue(self: Slider, value: f32) Slider
pub fn withStep(self: Slider, step: f32) Slider
pub fn withOrientation(self: Slider, orientation: SliderOrientation) Slider
pub fn withOnChange(self: Slider, callback: *const fn (f32) void) Slider
pub fn setValue(self: *Slider, value: f32) void
pub fn getValue(self: *Slider) f32
```

## Example

```zig
const VolumeControl = struct {
    volume: tui.Slider,

    pub fn init() VolumeControl {
        return .{
            .volume = tui.Slider.init(0.0, 100.0)
                .withValue(75.0)
                .withStep(5.0),
        };
    }

    pub fn render(self: *VolumeControl, ctx: *tui.RenderContext) void {
        var screen = ctx.getSubScreen();
        
        screen.moveCursor(2, 2);
        screen.putString("Volume:");
        
        const rect = tui.Rect{ .x = 2, .y = 3, .width = 40, .height = 2 };
        var slider_ctx = ctx.child(rect);
        self.volume.render(&slider_ctx);
    }

    pub fn handleEvent(self: *VolumeControl, event: tui.Event) tui.EventResult {
        return self.volume.handleEvent(event);
    }
};
```

## Keyboard Controls

- `←` / `↓` - Decrease value
- `→` / `↑` - Increase value
- `Home` - Minimum value
- `End` - Maximum value
