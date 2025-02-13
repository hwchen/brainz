const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const optimize = b.standardOptimizeOption(.{});

    // Build options
    const build_options_step = b.addOptions();

    const trace_value = b.option(bool, "trace", "enable tracing instructions for interpreter") orelse false;
    build_options_step.addOption(bool, "TRACE", trace_value);

    const debug_ops_value = b.option(bool, "debug-ops", "enable debug output for ops") orelse false;
    build_options_step.addOption(bool, "DEBUG_OPS", debug_ops_value);

    const stages = [_][]const u8{
        "og",
        "opt1",
        "opt2",
    };

    const test_step = b.step("test", "Run unit tests");

    inline for (stages) |stage| {
        var exe_mod = b.createModule(.{
            .root_source_file = b.path("src/" ++ stage ++ ".zig"),
            .target = target,
            .optimize = optimize,
        });
        exe_mod.addOptions("build_options", build_options_step);
        const exe = b.addExecutable(.{
            .name = stage,
            .root_module = exe_mod,
        });
        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step = b.step(stage, "Run " ++ stage);
        run_step.dependOn(&run_cmd.step);

        const exe_tests = b.addTest(.{
            .root_module = exe_mod,
        });
        const run_exe_tests = b.addRunArtifact(exe_tests);
        test_step.dependOn(&run_exe_tests.step);
    }
}
