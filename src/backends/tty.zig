const std = @import("std");
const builtin = @import("builtin");

comptime {
    if (builtin.os.tag == .windows) {
        @compileError("tty is not supported on Windows");
    }
}

const c = @cImport({
    @cInclude("sys/select.h");
});

extern "c" fn select(
    nfds: c_int,
    readfds: [*c]c.fd_set,
    writefds: [*c]c.fd_set,
    errorfds: [*c]c.fd_set,
    timeout: [*c]c.timeval,
) c_int;

const SelectError = error{Failure};

fn selectReadTimeout(tty: std.fs.File, nanoseconds: u64) SelectError!bool {
    // You are supposed to use c.FD_ZERO(&rd), but there's a bug - https://github.com/ziglang/zig/issues/10123
    // Luckily std.mem.zeroes does exactly the same thing for extern structs
    var rd: c.fd_set = std.mem.zeroes(c.fd_set);
    c.FD_SET(tty.handle, &rd);

    var tv: c.timeval = .{};
    tv.tv_sec = 0;
    tv.tv_usec = @intCast(nanoseconds / std.time.ns_per_us);

    const ret = select(tty.handle + 1, &rd, null, null, &tv);
    return switch (ret) {
        -1 => error.Failure,
        0 => false,
        else => true,
    };
}

pub const ReportMode = enum(u3) {
    not_recognized = 0,
    set = 1,
    reset = 2,
    permanently_set = 3,
    permanently_reset = 4,
};

pub fn requestMode(allocator: std.mem.Allocator, mode: u32) !ReportMode {
    const tty = try std.fs.cwd().openFile("/dev/tty", .{ .mode = .read_write });

    // DECRQM: CSI ? Pd $ p - https://vt100.net/docs/vt510-rm/DECRQM.html
    // DECRPM: CSI ? Pd; Ps $ y - https://vt100.net/docs/vt510-rm/DECRPM.html
    const CSI = "\x1B[";

    // Request mode
    try std.fmt.format(tty.writer(), CSI ++ "?{d}$p", .{mode});

    // Report mode
    const mode_str_len = std.fmt.count("{d}", .{mode});
    const buf = try allocator.alloc(u8, CSI.len + mode_str_len + 5);
    defer allocator.free(buf);

    const timeout_ns = 100 * std.time.ns_per_ms;

    switch (builtin.os.tag) {
        .macos => {
            // Can't use poll here because macOS doesn't support polling from /dev/tty* files.
            if (!try selectReadTimeout(tty, timeout_ns)) {
                return .not_recognized;
            }
            const read_bytes = try tty.read(buf);
            if (read_bytes != buf.len) {
                return .not_recognized;
            }
        },
        else => {
            var poller = std.io.poll(allocator, enum { tty }, .{ .tty = tty });
            defer poller.deinit();
            if (!try poller.pollTimeout(timeout_ns)) {
                return .not_recognized;
            }
            const fifo = poller.fifo(.tty);
            if (fifo.readableLength() != buf.len) {
                return .not_recognized;
            }
            std.mem.copyForwards(u8, buf, fifo.buf[0..buf.len]);
        },
    }
    const ps = try std.fmt.charToDigit(buf[CSI.len + 1 + mode_str_len + 1], 10);
    return try std.meta.intToEnum(ReportMode, ps);
}
