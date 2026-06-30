# Installation

## Prerequisites

- **Zig 0.16.0** or later — [Download Zig](https://ziglang.org/download/)
- No other dependencies required — TUI.zig is a pure Zig library

## Install via Zig Package Manager (Recommended)

### Stable Release ([v0.0.2](https://github.com/muhammad-fiaz/tui.zig/releases/tag/0.0.2))

Add TUI.zig as a dependency in your `build.zig.zon`:

```zig
.{
    .name = "your-project",
    .version = "0.0.1",
    .dependencies = .{
        .tui = .{
            .url = "https://github.com/muhammad-fiaz/tui.zig/archive/refs/tags/0.0.2.tar.gz",
            .hash = "1220____",  // run `zig build` to get the correct hash
        },
    },
    .paths = .{""},
}
```

### Latest Development Version

Use the `main` branch for the latest features:

```zig
.{
    .name = "your-project",
    .version = "0.0.1",
    .dependencies = .{
        .tui = .{
            .url = "https://github.com/muhammad-fiaz/tui.zig/archive/refs/heads/main.tar.gz",
            .hash = "1220____",  // run `zig build` to get the correct hash
        },
    },
    .paths = .{""},
}
```

Then in your `build.zig`:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const tui_dep = b.dependency("tui", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "my-app",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    exe.root_module.addImport("tui", tui_dep.module("tui"));
    b.installArtifact(exe);
}
```

## Build from Source

```bash
git clone https://github.com/muhammad-fiaz/tui.zig.git
cd tui.zig
zig build           # Build the library
zig build test      # Run all tests
zig build install   # Install to prefix path
```

## Quick Verification

After installation, verify it works:

```zig
const tui = @import("tui");

test "TUI.zig imports" {
    // Verify the library is accessible
    _ = tui.App;
    _ = tui.Button;
    _ = tui.Text;
}
```

Run with:

```bash
zig build test
```

## Platform Support

| Platform | Status |
|----------|--------|
| Linux    | Full support |
| macOS    | Full support |
| Windows  | Full support (ConPTY) |

## Next Steps

- [Getting Started](/guide/getting-started) — Build your first TUI application
- [Widgets](/guide/widgets) — Explore all 36+ built-in widgets
- [Themes](/guide/themes) — Customize your app's appearance
