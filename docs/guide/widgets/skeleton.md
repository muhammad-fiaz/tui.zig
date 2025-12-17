# Skeleton Widget

## Overview

The `Skeleton` widget displays animated loading placeholders while content is being loaded. It supports different variants (text, circle, rectangle) with customizable dimensions and animation control.

## Properties

- `variant`: The shape variant (`.text`, `.circle`, `.rectangle`)
- `width`: Width of the skeleton
- `height`: Height of the skeleton
- `animate`: Whether to animate the shimmer effect
- `animation_offset`: Current animation position
- `base`: Base widget state

## Methods

- `init(variant: SkeletonVariant)`: Creates a new skeleton with the specified variant
- `withSize(width: u16, height: u16)`: Sets the skeleton dimensions
- `withAnimate(animate: bool)`: Enables or disables animation
- `update()`: Updates the animation state
- `render(ctx: *RenderContext)`: Renders the skeleton with shimmer effect

## Events

None - this widget is not interactive.

## Examples

### Basic Rectangle Skeleton

```zig
const tui = @import("tui");
const Skeleton = tui.widgets.Skeleton;

var skeleton = Skeleton.init(.rectangle)
    .withSize(20, 1);
```

### Animated Circle Skeleton

```zig
var skeleton = Skeleton.init(.circle)
    .withSize(10, 10)
    .withAnimate(true);
```

### Text Loading Placeholder

```zig
var skeleton = Skeleton.init(.text)
    .withSize(30, 3);
```