---
title: Animations, Effects & Custom Loops
description: Build smooth Easing curves, Tweens, Springs, Transitions, Skeleton loading shimmers, buffer visual effects, ToastTimers, and explicit client event loops.
keywords: tui animations, Tween, Spring, Easing, Skeleton loading, shimmer effect, dissolve transition, custom event loop zig
---

# Animations, Effects & Custom Loops

**tui.zig** includes a built-in zero-allocation animation, transition, and post-render buffer effects engine (`tui.effects` / `tui.fx`) alongside deterministic millisecond timing inside both `app.run()` and explicit client-owned loops.

## Easing, `Tween` & `Spring` Physics

Drive meters, slides, fades, and loading indicators cleanly without heap churn:

```zig
var tw = tui.Tween.init(0.0, 1.0, 450, .ease_out_cubic);
tw.mode = .ping_pong;

var sp = tui.Spring.init(0.0);
sp.setTarget(0.85);

// Inside onEvent(.tick) or custom frame loop:
const dt = app.deltaMs();
_ = tw.advance(dt);
_ = sp.step(dt);
```

- Supported easing curves (`tui.Easing`): `.linear`, `.ease_in_quad`, `.ease_out_quad`, `.ease_in_out_quad`, `.ease_in_cubic`, `.ease_out_cubic`, `.ease_in_out_cubic`, `.ease_in_out_sine`, `.ease_out_back`, `.ease_out_bounce`.

## Visibility Transitions, Loading Skeletons & Toasts

- **`tui.Transition`**: bidirectional open/close progress (`0.0..1.0`) with `animatedRect(full_rect, origin)` supporting `.center`, `.top`, `.bottom`, `.left`, and `.right` reveals.
- **`tui.Skeleton`** (`ui.skeleton`): animated horizontal shimmer bars for loading states before data resolves.
- **`tui.ToastState`**: auto-dismissing toast queue with bottom progress bar and smooth fade transitions (`show`, `update(dt)`, `dismiss`, `render(ui, screen)`).

## Post-Render Buffer Effects (`tui.fx`)

Apply zero-allocation effects to any region of `ui.buffer` after rendering widgets:

- `tui.fx.fade(buf, area, backdrop_color, alpha)`
- `tui.fx.dimBackdrop(buf, area, strength)`
- `tui.fx.dissolve(buf, area, progress, seed)`
- `tui.fx.sweepWipe(buf, area, .horizontal, progress, edge_color)`
- `tui.fx.shimmer(buf, area, phase, highlight_color, width)`
- `tui.fx.pulseHighlight(buf, area, phase, glow_color)`
- `tui.fx.typewriterSlice(text, max_graphemes)` / `tui.fx.marqueeSlice(text, offset_cols, width, &buf)`

## Explicit Client-Side Event Loop

Instead of calling `app.run()`, clients with custom job queues or async pollers can drive frames directly:

```zig
try app.enter();
defer app.restore();

const frame_ms: i32 = @intCast(app.targetFrameMs());
while (app.isRunning()) {
    const dt = app.advanceTimer();
    updateAnimations(&state, dt);

    var ui = try app.beginFrame();
    try render(&state, &ui);
    try app.endFrame(&ui);

    const ev = try app.pollEvent(frame_ms);
    if (ev != .none) handleInput(&state, ev, &app);
}
```
