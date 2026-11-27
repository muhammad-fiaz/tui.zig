---
title: Cross-Platform Backends
description: Windows Win32 Console API, POSIX termios/poll/TIOCGWINSZ/SIGWINCH, 32-bit and 64-bit targets, capability detection, and ANSI streams.
keywords: zig windows terminal, posix termios, cross-platform tui, 32-bit 64-bit zig, MemoryBackend
---

# Cross-Platform Backends

**tui.zig** runs natively on **Windows**, **Linux**, **macOS**, and **BSD** across both **32-bit and 64-bit** targets without linking external C terminal libraries.

## Backend Drivers (`BackendMode`)

| Mode | Target | Highlights |
|---|---|---|
| `.auto` | Any OS | Chooses `.windows` on Windows, `.posix` on Unix/macOS, or `.memory` fallback on freestanding |
| `.windows` | Windows 10/11 | Win32 Console API, `ReadConsoleInputW` Unicode/mouse/resize events, CP 65001 UTF-8, ConPTY pipe fallback, VT mode restoration |
| `.posix` | Linux/macOS/BSD | Native `termios` raw mode, non-blocking `poll`, `TIOCGWINSZ` sizing, `SIGWINCH` signal pipe, VT sequence parsing |
| `.ansi` | Any `std.Io.File` | Pure VT writer without OS TTY mode mutation |
| `.{ .memory = size }` | Headless / CI | Deterministic in-memory grid with synthetic event queue & text snapshots |

## Selecting a Backend & Inspecting Capabilities

```zig
const std = @import("std");
const tui = @import("tui");

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const headless = tui.hasArg(init.minimal.args, alloc, "--headless");

    var app = try tui.init(alloc, .{
        .io = init.io,
        .backend = if (headless) .{ .memory = .{ .width = 80, .height = 24 } } else .auto,
        .capability = null, // auto-detect, or override with .trueColor / .ansi256
    });
    defer app.deinit();

    const caps = app.capabilities();
    _ = caps.color; // .trueColor, .ansi256, .ansi16, or .monochrome
}
```

## Environment Capability Detection

`capabilities.detect` honors `NO_COLOR`, `CLICOLOR_FORCE`, `TERM=dumb`, `COLORTERM=truecolor`, `WT_SESSION`, and `TERM_PROGRAM` (WezTerm, iTerm.app, Ghostty, VS Code, Kitty, Apple Terminal) on both Windows and POSIX (reading `/proc/self/environ` on non-libc Linux or `getenv` when libc is linked). Override anytime via `.capability = .trueColor` or `.ansi256` inside `AppOptions`.
