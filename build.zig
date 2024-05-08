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
            const use_prebuilt = b.option(bool, "prebuilt", "Use prebuilt crossterm library") orelse true;

            const build_crab = @import("build.crab");
            var crossterm_lib_path: std.Build.LazyPath = undefined;

            if (use_prebuilt) {
                const rust_target = build_crab.Target.fromZig(@import("builtin").target) catch @panic("unable to convert target triple to Rust");
                std.log.info("Using prebuilt crossterm backend for target {}", .{rust_target});
                const prebuilt_name = b.fmt("tuile-crossterm-{}", .{rust_target});
                const prebuilt = b.dependency(prebuilt_name, .{});
                crossterm_lib_path = prebuilt.path("libtuile_crossterm.a");
            } else {
                std.log.info("Building crossterm backend from source", .{});
                const tuile_crossterm = b.dependency("tuile-crossterm", .{});
                crossterm_lib_path = build_crab.addRustStaticlibWithUserOptions(
                    b,
                    .{
                        .name = "libtuile_crossterm.a",
                        .manifest_path = tuile_crossterm.path("Cargo.toml"),
                        .cargo_args = &.{
                            "--release",
                            "--quiet",
                        },
                    },
                    .{ .optimize = .ReleaseSafe },
                );
            }

            module.link_libcpp = true;
            module.addLibraryPath(crossterm_lib_path.dirname());
            module.linkSystemLibrary("tuile_crossterm", .{});

            lib_unit_tests.linkLibCpp();
            lib_unit_tests.addLibraryPath(crossterm_lib_path.dirname());
            lib_unit_tests.linkSystemLibrary("tuile_crossterm");
        },
    }

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    run_lib_unit_tests.has_side_effects = true;

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}

fn requestedBackend(b: *std.Build) Backend {
    const default_backend = switch (@import("builtin").target.os.tag) {
        .windows => Backend.crossterm,
        // else => Backend.ncurses,
        else => Backend.crossterm,
    };
    const backend_str = @tagName(b.option(Backend, "backend", "Terminal manipulation backend") orelse default_backend);

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
