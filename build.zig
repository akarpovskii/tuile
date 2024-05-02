const std = @import("std");

const Backend = enum {
    ncurses,
    crossterm,
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const backend = requestedBackend(b);
    const options = b.addOptions();
    options.addOption(Backend, "backend", backend);

    const module = b.addModule("tuile", .{
        .root_source_file = .{ .path = "src/tuile.zig" },
        .target = target,
        .optimize = optimize,
    });

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
    });

    module.addOptions("build_options", options);
    lib_unit_tests.root_module.addOptions("build_options", options);

    switch (backend) {
        .ncurses => {
            module.link_libc = true;
            module.linkSystemLibrary("ncurses", .{});

            lib_unit_tests.linkLibC();
            lib_unit_tests.linkSystemLibrary("ncurses");
        },
        .crossterm => {
            const build_crab = b.dependency("build.crab", .{
                .optimize = .ReleaseSafe,
            });

            const build_crossterm = b.addRunArtifact(build_crab.artifact("build_crab"));

            build_crossterm.addArg("--out");
            const crossterm_lib_path = build_crossterm.addOutputFileArg("libcrossterm.a");

            build_crossterm.addArg("--deps");
            _ = build_crossterm.addDepFileOutputArg("libcrossterm.d");

            build_crossterm.addArg("--manifest-path");
            _ = build_crossterm.addFileArg(b.path("src/backends/crossterm/Cargo.toml"));

            const cargo_target = b.addNamedWriteFiles("cargo-target");
            const target_dir = cargo_target.getDirectory();
            build_crossterm.addArg("--target-dir");
            build_crossterm.addDirectoryArg(target_dir);

            build_crossterm.addArgs(&[_][]const u8{
                "--",
                "--release",
                "--quiet",
            });

            module.link_libc = true;
            module.addLibraryPath(crossterm_lib_path.dirname());
            module.linkSystemLibrary("crossterm", .{});

            lib_unit_tests.linkLibC();
            lib_unit_tests.addLibraryPath(crossterm_lib_path.dirname());
            lib_unit_tests.linkSystemLibrary("crossterm");
        },
    }

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    run_lib_unit_tests.has_side_effects = true;

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}

fn requestedBackend(b: *std.Build) Backend {
    const backend_str = b.option([]const u8, "backend", "Backend") orelse @tagName(Backend.ncurses);

    var backend: Backend = undefined;
    if (std.ascii.eqlIgnoreCase(backend_str, @tagName(Backend.ncurses))) {
        backend = .ncurses;
    } else if (std.ascii.eqlIgnoreCase(backend_str, @tagName(Backend.crossterm))) {
        backend = .crossterm;
    } else {
        const names = comptime blk: {
            const info = @typeInfo(Backend);
            const fields = info.Enum.fields;
            var names: [fields.len][]const u8 = undefined;
            for (&names, fields) |*name, field| {
                name.* = field.name;
            }
            break :blk names;
        };

        @panic(b.fmt(
            "Option {s} is not a valid backend. Valid options are: {}",
            .{ backend_str, std.json.fmt(names, .{}) },
        ));
    }
    return backend;
}
