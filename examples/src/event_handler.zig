const std = @import("std");
const tuile = @import("tuile");

pub fn stopOnQ(ptr: ?*anyopaque, event: tuile.events.Event) !tuile.events.EventResult {
    var tui: *tuile.Tuile = @ptrCast(@alignCast(ptr));
    switch (event) {
        .char => |char| if (char == 'q') {
            tui.stop();
            return .consumed;
        },
        else => {},
    }
    return .ignored;
}

pub fn main() !void {
    var tui = try tuile.Tuile.init(.{});
    defer tui.deinit();

    const layout = tuile.vertical(
        .{ .layout = .{ .flex = 1 } },
        .{tuile.block(
            .{ .layout = .{ .flex = 1 } },
            tuile.label(.{ .text = "Press q to exit" }),
        )},
    );

    try tui.add(layout);
    try tui.addEventHandler(.{
        .handler = stopOnQ,
        .payload = &tui,
    });

    try tui.run();
}
