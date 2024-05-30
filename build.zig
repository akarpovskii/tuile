const std = @import("std");

const Backend = enum {
    ncurses,
    crossterm,
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const user_options = Options.init(b);

    const module_options = b.addOptions();
    module_options.addOption(Backend, "backend", user_options.backend);

    const module = b.addModule("tuile", .{
        .root_source_file = b.path("src/tuile.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
    });

    module.addOptions("build_options", module_options);
    lib_unit_tests.root_module.addOptions("build_options", module_options);

    const zg = b.dependency("zg", .{});
    module.addImport("grapheme", zg.module("grapheme"));
    module.addImport("DisplayWidth", zg.module("DisplayWidth"));
    lib_unit_tests.root_module.addImport("grapheme", zg.module("grapheme"));
    lib_unit_tests.root_module.addImport("DisplayWidth", zg.module("DisplayWidth"));

    switch (user_options.backend) {
        .ncurses => {
            module.link_libc = true;
            module.linkSystemLibrary("ncurses", .{});

            lib_unit_tests.linkLibC();
            lib_unit_tests.linkSystemLibrary("ncurses");
        },
        .crossterm => {
            const build_crab = @import("build.crab");
            var crossterm_lib_path: std.Build.LazyPath = undefined;

            if (user_options.prebuilt) {
                const rust_target = build_crab.Target.fromZig(target.result) catch @panic("unable to convert target triple to Rust");
                const prebuilt_name = b.fmt("tuile-crossterm-{}", .{rust_target});
                const prebuilt_opt = b.lazyDependency(prebuilt_name, .{});
                if (prebuilt_opt == null) {
                    return;
                }
                std.log.info("Using prebuilt crossterm backend for target {}", .{rust_target});
                const prebuilt = prebuilt_opt.?;
                crossterm_lib_path = prebuilt.path("libtuile_crossterm.a");
            } else {
                const tuile_crossterm_opt = b.lazyDependency("tuile-crossterm", .{});
                if (tuile_crossterm_opt == null) {
                    return;
                }
                std.log.info("Building crossterm backend from source", .{});
                const tuile_crossterm = tuile_crossterm_opt.?;
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
                    .{ .target = target, .optimize = .ReleaseSafe },
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

pub const Options = struct {
    backend: Backend = .crossterm,
    prebuilt: bool = true,

    pub fn init(b: *std.Build) Options {
        var opts: Options = .{};
        opts.backend = requestedBackend(b) orelse opts.backend;
        opts.prebuilt = b.option(bool, "prebuilt", "Use prebuilt crossterm backend") orelse opts.prebuilt;
        if (opts.prebuilt and opts.backend != .crossterm) {
            @panic("prebuilt option is only available with crossterm backend");
        }
        return opts;
    }

    fn requestedBackend(b: *std.Build) ?Backend {
        const backend_str = @tagName(b.option(Backend, "backend", "Terminal manipulation backend") orelse return null);

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
};
