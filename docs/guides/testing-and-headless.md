---
title: Headless Testing & CI Verification
description: Write deterministic unit and integration tests using MemoryBackend, synthetic event queues, resize simulation, and snapshot assertions.
keywords: tui headless testing, MemoryBackend zig, app snapshot, pushTestEvent, resizeTest, std.testing
---

# Headless Testing & CI Verification

Every screen built with **tui.zig** can be tested end-to-end inside `std.testing` or `--headless` CI executables without spawning a pseudo-terminal.

## Injecting Events & Capturing Snapshots

```zig
test "dashboard responds to resize and keyboard shortcuts" {
    var app = try tui.init(std.testing.allocator, .{
        .io = std.testing.io,
        .backend = .{ .memory = .{ .width = 80, .height = 24 } },
    });
    defer app.deinit();

    var state = State{};
    try app.draw(&state, render);

    try app.resizeTest(.{ .width = 40, .height = 12 });
    try app.pushTestEvent(.{ .key = .{ .code = .{ .char = 'n' } } });
    try app.draw(&state, render);

    const snap = try app.snapshot();
    try std.testing.expect(std.mem.indexOf(u8, snap, "40x12") != null);
}
```

## Checking Every Example in CI

All 39 examples inspect `tui.hasArg(init.minimal.args, alloc, "--headless")`, switch to `.memory`, exercise key/mouse/resize transitions, assert screen contents, and exit cleanly:

```sh
zig build test
zig build run-all-examples
```
