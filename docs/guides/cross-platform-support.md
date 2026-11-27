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

## Environment Capability Detection

`capabilities.detect` honors `NO_COLOR`, `CLICOLOR_FORCE`, `TERM=dumb`, `COLORTERM=truecolor`, `WT_SESSION`, and `TERM_PROGRAM` (WezTerm, iTerm.app, Ghostty, VS Code, Kitty, Apple Terminal) on both Windows and POSIX (reading `/proc/self/environ` on non-libc Linux or `getenv` when libc is linked). Override anytime via `.capability = .trueColor` or `.ansi256` inside `AppOptions`.
