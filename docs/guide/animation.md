# Animation

TUI.zig includes a built-in animation system for creating smooth transitions and effects.

## Concepts

- **Animation**: Interpolates a value between start and end over time.
- **Easing**: Controls the rate of change (e.g., linear, bounce, elastic).
- **Timer**: Triggers callbacks after a delay or interval.

## Creating Animations

Use the generic `Animation(T)` struct:

```zig
const std = @import("std");
const tui = @import("tui");

// ... inside your widget struct ...
pos_anim: tui.animation.Animation(f32),

pub fn init() MyWidget {
    return .{
        // Animate from 0.0 to 100.0 over 1 second (1000ms)
        .pos_anim = tui.animation.Animation(f32).init(0.0, 100.0, 1000)
            .withEasing(tui.animation.Easing.easeOutBounce),
    };
}

pub fn startMyAnimation(self: *MyWidget) void {
    self.pos_anim.start();
}

pub fn update(self: *MyWidget) void {
    // Calling update with delta time (e.g. 16ms for 60fps)
    self.pos_anim.update(16);
}

pub fn render(self: *MyWidget, ctx: *RenderContext) void {
    const current_pos = self.pos_anim.getValue();
    // Render at current_pos...
}
```

## Easing Functions

Available easing functions in `tui.animation.Easing`:

- **Linear**: `linear`
- **Quad**: `easeInQuad`, `easeOutQuad`, `easeInOutQuad`
- **Cubic**: `easeInCubic`, `easeOutCubic`, `easeInOutCubic`
- **Quart**: `easeInQuart`, `easeOutQuart`, `easeInOutQuart`
- **Quint**: `easeInQuint`, `easeOutQuint`, `easeInOutQuint`
- **Sine**: `easeInSine`, `easeOutSine`, `easeInOutSine`
- **Expo**: `easeInExpo`, `easeOutExpo`, `easeInOutExpo`
- **Circ**: `easeInCirc`, `easeOutCirc`, `easeInOutCirc`
- **Back**: `easeInBack`, `easeOutBack`, `easeInOutBack` (overshoot)
- **Elastic**: `easeInElastic`, `easeOutElastic`, `easeInOutElastic`
- **Bounce**: `easeInBounce`, `easeOutBounce`, `easeInOutBounce`

## Timers

Use timers for delayed actions or periodic updates:

```zig
// One-shot timer (fire once after 500ms)
var timer = tui.animation.Timer.oneShot(500, onTimerDone);

// Repeating timer (fire every 100ms)
var ticker = tui.animation.Timer.repeating_timer(100, onTick);
```

## Animation Loop

In `App`, animations are updated automatically if you use the built-in system. However, specific widget animations often rely on the widget's `render` or `handleEvent` to progress state, or manual updating if you manage the loop.

Standard widgets like `Spinner` handle their own internal tick state, usually requiring you to call a `tick()` method or similar in your update loop.
