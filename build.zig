const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

 
    _ = b.addModule("tui", .{
        .root_source_file = b.path("src/tui.zig"),
    });


    const lib = b.addLibrary(.{
        .name = "tui",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tui.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(lib);


    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/tui.zig"),
        .target = target,
        .optimize = optimize,
    });

    const unit_tests = b.addTest(.{
        .root_module = test_mod,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    // Examples removed - focus on library development and testing
}
