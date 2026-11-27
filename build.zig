const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const tint_dep = b.dependency("tint", .{
        .target = target,
        .optimize = optimize,
    });
    const zigantic_dep = b.dependency("zigantic", .{
        .target = target,
        .optimize = optimize,
    });

    const tint_mod = tint_dep.module("tint");
    const zigantic_mod = zigantic_dep.module("zigantic");

    const tui_mod = b.addModule("tui", .{
        .root_source_file = b.path("src/tui.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "tint", .module = tint_mod },
            .{ .name = "zigantic", .module = zigantic_mod },
        },
    });

    const lib = b.addLibrary(.{
        .name = "tui",
        .linkage = .static,
        .root_module = tui_mod,
    });
    b.installArtifact(lib);

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tui.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "tint", .module = tint_mod },
                .{ .name = "zigantic", .module = zigantic_mod },
            },
        }),
    });

    const test_step = b.step("test", "Run the unit and integration test suite");
    const builtin = @import("builtin");
    if (target.result.os.tag == builtin.os.tag and target.result.cpu.arch == builtin.cpu.arch) {
        test_step.dependOn(&b.addRunArtifact(tests).step);
    } else {
        test_step.dependOn(&b.addInstallArtifact(tests, .{}).step);
    }

    const examples_step = b.step("examples", "Compile all example applications");
    const run_all_examples_step = b.step("run-all-examples", "Run all examples in non-interactive snapshot mode");

    const ExampleSpec = struct {
        name: []const u8,
        path: []const u8,
    };
    const example_specs = [_]ExampleSpec{
        .{ .name = "hello-world", .path = "examples/hello_world.zig" },
        .{ .name = "basic-layout", .path = "examples/basic_layout.zig" },
        .{ .name = "styling", .path = "examples/styling.zig" },
        .{ .name = "colors", .path = "examples/colors.zig" },
        .{ .name = "borders", .path = "examples/borders.zig" },
        .{ .name = "paragraph", .path = "examples/paragraph.zig" },
        .{ .name = "text-input", .path = "examples/text_input.zig" },
        .{ .name = "buttons", .path = "examples/buttons.zig" },
        .{ .name = "checkbox", .path = "examples/checkbox.zig" },
        .{ .name = "radio", .path = "examples/radio.zig" },
        .{ .name = "list", .path = "examples/list.zig" },
        .{ .name = "table", .path = "examples/table.zig" },
        .{ .name = "tabs", .path = "examples/tabs.zig" },
        .{ .name = "progress", .path = "examples/progress.zig" },
        .{ .name = "gauge", .path = "examples/gauge.zig" },
        .{ .name = "scrollbar", .path = "examples/scrollbar.zig" },
        .{ .name = "popup", .path = "examples/popup.zig" },
        .{ .name = "events", .path = "examples/events.zig" },
        .{ .name = "mouse", .path = "examples/mouse.zig" },
        .{ .name = "custom-widget", .path = "examples/custom_widget.zig" },
        .{ .name = "custom-ui", .path = "examples/custom_ui.zig" },
        .{ .name = "custom-stateful-widget", .path = "examples/custom_stateful_widget.zig" },
        .{ .name = "animations-effects", .path = "examples/animations_and_effects.zig" },
        .{ .name = "custom-loop", .path = "examples/custom_event_loop.zig" },
        .{ .name = "stateful-widgets", .path = "examples/stateful_widgets.zig" },
        .{ .name = "charts", .path = "examples/charts.zig" },
        .{ .name = "canvas", .path = "examples/canvas.zig" },
        .{ .name = "terminal-resize", .path = "examples/terminal_resize.zig" },
        .{ .name = "calendar", .path = "examples/calendar.zig" },
        .{ .name = "controls", .path = "examples/controls.zig" },
        .{ .name = "markdown-palette", .path = "examples/markdown_and_palette.zig" },
        .{ .name = "inline-viewport", .path = "examples/inline_viewport.zig" },
        .{ .name = "dashboard", .path = "examples/advanced/dashboard.zig" },
        .{ .name = "file-browser", .path = "examples/advanced/file_browser.zig" },
        .{ .name = "system-monitor", .path = "examples/advanced/system_monitor.zig" },
        .{ .name = "interactive-menu", .path = "examples/advanced/interactive_menu.zig" },
        .{ .name = "app-shell", .path = "examples/app_shell.zig" },
        .{ .name = "custom-fonts-i18n", .path = "examples/custom_fonts_and_i18n.zig" },
    };

    inline for (example_specs) |spec| {
        const exe = b.addExecutable(.{
            .name = spec.name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(spec.path),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "tui", .module = tui_mod },
                },
            }),
        });

        const install_exe = b.addInstallArtifact(exe, .{});
        examples_step.dependOn(&install_exe.step);
        b.step("example-" ++ spec.name, "Build the " ++ spec.name ++ " example").dependOn(&install_exe.step);

        const run_exe = b.addRunArtifact(exe);
        run_exe.step.dependOn(&install_exe.step);
        run_exe.addPassthruArgs();
        b.step("run-" ++ spec.name, "Run the " ++ spec.name ++ " example").dependOn(&run_exe.step);

        const run_batch = b.addRunArtifact(exe);
        run_batch.step.dependOn(&install_exe.step);
        run_batch.addArg("--headless");
        run_all_examples_step.dependOn(&run_batch.step);
    }

    const docs_obj = b.addObject(.{
        .name = "tui",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tui.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "tint", .module = tint_mod },
                .{ .name = "zigantic", .module = zigantic_mod },
            },
        }),
    });
    const install_docs = b.addInstallDirectory(.{
        .source_dir = docs_obj.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    b.step("docs", "Generate Zig API documentation into zig-out/docs").dependOn(&install_docs.step);
}
