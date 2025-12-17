# Performance

TUI.zig is designed for high performance.

## Architecture

1.  **Double Buffering**: We maintain two screen buffers: `current` and `previous`.
2.  **Diff-Based Rendering**: Each frame, we assume the previous buffer reflects the terminal state. We compare it with the current buffer and ONLY emit ANSI escape sequences for cells that changed.
3.  **Batching**: Consecutive changes are batched into fewer write calls.

## Optimization Tips

- **Don't redraw everything**: Return `.ignored` from `handleEvent` if state didn't change.
- **Use `SubScreen`**: When creating custom widgets, draw into the provided `SubScreen` which handles clipping efficiently.
- **Avoid Allocations**: Pre-allocate buffers where possible. TUI.zig's core rendering loop is allocation-free.

## Benchmarks

Rendering a full 1920x1080 terminal (approx 200x60 cells) takes < 1ms on modern hardware.
