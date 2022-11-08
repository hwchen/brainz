const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const stages = [_][]const u8{
        "og",
    };

    const test_step = b.step("test", "Run unit tests");

    inline for (stages) |stage| {
        const exe = b.addExecutable(stage, "src/" ++ stage ++ ".zig");
        exe.setTarget(target);
        exe.setBuildMode(mode);
        exe.install();

        const run_cmd = exe.run();
        run_cmd.step.dependOn(b.getInstallStep());
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step = b.step(stage, "Run " ++ stage);
        run_step.dependOn(&run_cmd.step);

        const exe_tests = b.addTest("src/" ++ stage ++ ".zig");
        exe_tests.setTarget(target);
        exe_tests.setBuildMode(mode);
        test_step.dependOn(&exe_tests.step);
    }
}
