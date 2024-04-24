const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const tuile = b.dependency("tuile", .{});

    const executables: []const []const u8 = &.{
        "demo",
        "input",
        "threads",
        "checkbox",
        "fps_counter",
    };
    inline for (executables) |name| {
        const exe = b.addExecutable(.{
            .name = name,
            .root_source_file = b.path("src/" ++ name ++ ".zig"),
            .target = target,
            .optimize = optimize,
        });

        exe.root_module.addImport("tuile", tuile.module("tuile"));
        exe.linkSystemLibrary("ncurses");

        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());

        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step = b.step(name, "Run " ++ name ++ " example");
        run_step.dependOn(&run_cmd.step);
    }
}