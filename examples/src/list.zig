const std = @import("std");
const tuile = @import("tuile");

pub fn main() !void {
    var tui = try tuile.Tuile.init(.{});
    defer tui.deinit();

    const layout = tuile.block(
        .{ .layout = .{ .max_height = 4 }, .border_type = .solid, .border = tuile.Border.all() },
        tuile.list(
            .{},
            &.{
                .{
                    .label = try tuile.label(.{ .text = "Item 1\nNew line 1\nNew line 2" }),
                    .value = null,
                },
                .{
                    .label = try tuile.label(.{ .text = "Item 2" }),
                    .value = null,
                },
                .{
                    .label = try tuile.label(.{ .text = "Item 3" }),
                    .value = null,
                },
                .{
                    .label = try tuile.label(.{ .text = "Item 4" }),
                    .value = null,
                },
                .{
                    .label = try tuile.label(.{ .text = "Item 5" }),
                    .value = null,
                },
            },
        ),
    );

    try tui.add(layout);
    try tui.run();
}
