# Animation

The animation module provides utilities for creating smooth transitions, easing functions, and timing controls for TUI applications.

## Overview

This module includes:
- Easing functions for various animation curves
- Generic animation system for numeric types
- FPS counter for performance monitoring

## Easing Functions

The `Easing` struct contains static methods for common easing functions. Each function takes a normalized time value `t` (0.0 to 1.0) and returns an eased value.

### Linear Easing

```zig
pub fn linear(t: f32) f32
```

Returns the input value unchanged.

### Quadratic Easing

```zig
pub fn easeInQuad(t: f32) f32
pub fn easeOutQuad(t: f32) f32
pub fn easeInOutQuad(t: f32) f32
```

### Cubic Easing

```zig
pub fn easeInCubic(t: f32) f32
pub fn easeOutCubic(t: f32) f32
pub fn easeInOutCubic(t: f32) f32
```

### Quartic Easing

```zig
pub fn easeInQuart(t: f32) f32
pub fn easeOutQuart(t: f32) f32
pub fn easeInOutQuart(t: f32) f32
```

### Quintic Easing

```zig
pub fn easeInQuint(t: f32) f32
pub fn easeOutQuint(t: f32) f32
pub fn easeInOutQuint(t: f32) f32
```

### Sine Easing

```zig
pub fn easeInSine(t: f32) f32
pub fn easeOutSine(t: f32) f32
pub fn easeInOutSine(t: f32) f32
```

### Exponential Easing

```zig
pub fn easeInExpo(t: f32) f32
pub fn easeOutExpo(t: f32) f32
pub fn easeInOutExpo(t: f32) f32
```

### Circular Easing

```zig
pub fn easeInCirc(t: f32) f32
pub fn easeOutCirc(t: f32) f32
pub fn easeInOutCirc(t: f32) f32
```

### Back Easing

```zig
pub fn easeInBack(t: f32) f32
pub fn easeOutBack(t: f32) f32
pub fn easeInOutBack(t: f32) f32
```

### Elastic Easing

```zig
pub fn easeInElastic(t: f32) f32
pub fn easeOutElastic(t: f32) f32
pub fn easeInOutElastic(t: f32) f32
```

### Bounce Easing

```zig
pub fn easeInBounce(t: f32) f32
pub fn easeOutBounce(t: f32) f32
pub fn easeInOutBounce(t: f32) f32
```

## Animation Types

### EasingFn

```zig
pub const EasingFn = *const fn (f32) f32;
```

Function pointer type for easing functions.

### AnimationState

```zig
pub const AnimationState = enum {
    idle,
    running,
    paused,
    completed,
};
```

Represents the current state of an animation.

### Animation(T)

Generic animation struct for any numeric type `T` that supports linear interpolation.

#### Fields

- `start_value: T` - The starting value
- `end_value: T` - The ending value
- `duration_ms: u32` - Duration in milliseconds
- `easing: EasingFn` - Easing function (default: linear)
- `progress: f32` - Current progress (0.0 to 1.0)
- `elapsed_ms: u32` - Elapsed time in milliseconds
- `state: AnimationState` - Current animation state
- `loop_count: u32` - Number of loops (0 = infinite)
- `current_loop: u32` - Current loop iteration
- `alternate: bool` - Whether to reverse direction on alternate loops
- `on_complete: ?*const fn () void` - Completion callback

#### Methods

##### init

```zig
pub fn init(start_val: T, end_val: T, duration_ms: u32) Self
```

Creates a new animation instance.

**Parameters:**
- `start_val: T` - Starting value
- `end_val: T` - Ending value
- `duration_ms: u32` - Duration in milliseconds

**Returns:** New Animation instance

##### withEasing

```zig
pub fn withEasing(self: Self, easing: EasingFn) Self
```

Sets the easing function.

**Parameters:**
- `easing: EasingFn` - Easing function to use

**Returns:** Modified Animation instance

##### loop

```zig
pub fn loop(self: Self, count: u32) Self
```

Sets the loop count.

**Parameters:**
- `count: u32` - Number of times to loop (0 = infinite)

**Returns:** Modified Animation instance

##### loopForever

```zig
pub fn loopForever(self: Self) Self
```

Enables infinite looping.

**Returns:** Modified Animation instance

##### withAlternate

```zig
pub fn withAlternate(self: Self) Self
```

Enables alternating (ping-pong) animation.

**Returns:** Modified Animation instance

##### start

```zig
pub fn start(self: *Self) void
```

Starts the animation.

##### pause

```zig
pub fn pause(self: *Self) void
```

Pauses the animation if running.

##### resumeAnimation

```zig
pub fn resumeAnimation(self: *Self) void
```

Resumes the animation if paused.

##### reset

```zig
pub fn reset(self: *Self) void
```

Resets the animation to initial state.

##### update

```zig
pub fn update(self: *Self, delta_ms: u32) void
```

Updates the animation state.

**Parameters:**
- `delta_ms: u32` - Time elapsed since last update in milliseconds

##### getValue

```zig
pub fn getValue(self: *Self) T
```

Gets the current interpolated value.

**Returns:** Current animation value

## FpsCounter

Utility for tracking frames per second.

### Fields

- `frame_times: [60]u32` - Ring buffer of frame times
- `index: usize` - Current buffer index
- `total_time: u32` - Sum of all frame times

### Methods

#### init

```zig
pub fn init() FpsCounter
```

Creates a new FPS counter initialized with 60 FPS.

**Returns:** New FpsCounter instance

#### update

```zig
pub fn update(self: *FpsCounter, delta_ms: u32) void
```

Updates the FPS counter with a new frame time.

**Parameters:**
- `delta_ms: u32` - Time taken for the last frame in milliseconds

#### getFps

```zig
pub fn getFps(self: *FpsCounter) u32
```

Calculates the current FPS based on recent frame times.

**Returns:** Current FPS value

## Usage Examples

### Basic Animation

```zig
const anim = Animation(f32).init(0.0, 100.0, 1000)
    .withEasing(&Easing.easeOutCubic);

// Start the animation
anim.start();

// In your update loop
anim.update(delta_ms);
const current_value = anim.getValue();
```

### Looping Animation

```zig
const anim = Animation(f32).init(0.0, 1.0, 500)
    .withEasing(&Easing.easeInOutSine)
    .loop(3)
    .withAlternate();
```

### FPS Monitoring

```zig
var fps_counter = FpsCounter.init();

// In your render loop
fps_counter.update(delta_ms);
const fps = fps_counter.getFps();
```

## See Also

- [Animation Guide](../guide/animation.md)
- Source: `src/animation/animation.zig`