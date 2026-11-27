---
title: Contributing
description: Development workflow, Zig 0.17.0+ coding standards, cross-target rules, and PR checklist for tui.zig.
keywords: contribute tui.zig, zig 0.17.0, zig build test, examples, pull request guidelines
---

# Contributing to tui.zig

Contributions are welcome! Full contribution rules live in [`CONTRIBUTING.md`](https://github.com/muhammad-fiaz/tui.zig/blob/main/CONTRIBUTING.md).

## Local Development Workflow

```sh
git clone https://github.com/muhammad-fiaz/tui.zig.git
cd tui.zig
zig build
zig build test
zig build examples
zig build run-all-examples
zig build docs
```

## Key Standards

- Target **Zig 0.17.0+** cleanly without deprecated stdlib APIs or C bindings.
- Keep code portable across 32-bit and 64-bit targets (`x86`, `x86_64`, `aarch64`, `arm`, `thumb`, `riscv32`) on Windows, Linux, and macOS.
- Require explicit `std.mem.Allocator` arguments for all owning APIs and avoid heap churn during steady-state rendering.
- Include unit tests at the bottom of every modified `src/` file and format changes with `zig fmt`.
- Support non-interactive `--headless` verification on every example program.
