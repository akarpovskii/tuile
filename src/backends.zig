pub const Backend = @import("backends/Backend.zig");
pub const Testing = @import("backends/Testing.zig");

const build_options = @import("build_options");
const backend = build_options.backend;

pub const Ncurses = if (backend == .ncurses)
    @import("backends/Ncurses.zig")
else
    undefined;

pub const Crossterm = if (backend == .crossterm)
    @import("backends/Crossterm.zig")
else
    undefined;

pub fn createBackend() !Backend {
    if (comptime backend == .ncurses) {
        return (try Ncurses.create()).backend();
    } else if (comptime backend == .crossterm) {
        return (try Crossterm.create()).backend();
    }
}
