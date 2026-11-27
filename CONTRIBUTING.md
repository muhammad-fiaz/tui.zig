# Contributing to tui.zig

Thank you for helping improve **tui.zig**! This library provides a native Zig **0.17.0+** terminal user interface framework with explicit memory ownership and zero C dependencies.

## Getting Started

1. Install **Zig 0.17.0+** from [ziglang.org](https://ziglang.org/download/) (`zig version`).
2. Clone the repository and run the library build and unit tests:

```sh
git clone https://github.com/muhammad-fiaz/tui.zig.git
cd tui.zig
zig build
zig build test
```

3. Build and validate all 38 runnable example programs:

```sh
zig build examples
zig build run-all-examples
```

4. Launch any individual interactive example (for instance `dashboard` or `custom-ui`):

```sh
zig build run-dashboard
```

## Coding & Architecture Standards

- **Target Compiler**: Code must compile cleanly on **Zig 0.17.0+** without deprecated stdlib APIs and pass cross-compilation across 32-bit and 64-bit Linux, Windows, macOS, ARM, RISC-V, and freestanding build targets.
- **Explicit Memory Ownership**: Never introduce hidden global allocators. All owning APIs accept `std.mem.Allocator` explicitly and implement clean `deinit()`. Keep steady-state per-frame rendering free of unnecessary heap allocations.
- **Widget Ergonomics**: New widgets should support composable struct usage (`render` / `renderStateful`) and flat convenience helpers on `tui.Ui` where appropriate, with sensible `.{}` default options.
- **Testing**: Place unit tests at the bottom of every modified or new module under `src/`, using `std.testing.allocator` to catch leaks and `tui.backend.MemoryBackend` for deterministic rendering assertions.
- **Formatting**: Format changed files before opening a PR using `zig fmt src examples build.zig build.zig.zon`.
- **Documentation**: Add concise Zig doc comments (`///`) to public types, fields, and functions, and keep `docs/` pages and examples up to date.

## Submitting Pull Requests

1. Fork the repository and create a topic branch (`git checkout -b feat/short-name`).
2. Verify all checks pass before submitting:

```sh
zig fmt --check src examples build.zig build.zig.zon
zig build
zig build test
zig build examples
zig build run-all-examples
zig build docs
```

3. Keep commits scoped, clearly titled, and explain the user-facing problem or enhancement in your PR description.

If you discover a security vulnerability rather than a general bug, please see [SECURITY.md](SECURITY.md).
