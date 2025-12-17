# Spinner Widget

Animated spinner for indeterminate loading states.

## Import

```zig
const tui = @import("tui");
const Spinner = tui.Spinner;
```

## Usage

```zig
// Initialize with a preset
var s = Spinner.initPreset(.dots);

// Or with a label
var s2 = Spinner.initWithLabel("Loading...");
```

## Presets

Available spinner presets (`Spinner.Preset`):

- `.dots`
- `.line`
- `.dots_scrolling`
- `.star`
- `.box_bounce`
- `.arrow`

## Animation

You can update the spinner based on the render context time.

```zig
pub fn render(self: *MyComp, ctx: *tui.RenderContext) void {
    // Return value indicates if redraw is needed (frames updated)
    _ = self.spinner.update(@intCast(ctx.time_ns));

    self.spinner.render(ctx);
}
```
