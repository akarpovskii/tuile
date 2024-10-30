const std = @import("std");
const tuile = @import("tuile");

pub fn main() !void {
    var tui = try tuile.Tuile.init(.{});
    defer tui.deinit();

    const layout = tuile.block(
        .{ .layout = .{ .max_height = 12 }, .border_type = .solid, .border = tuile.Border.all() },
        tuile.list(
            .{ .layout = .{ .alignment = tuile.Align.topCenter(), .min_height = 10 } },
            &.{
                .{
                    .label = try tuile.label(.{
                        // .text = "Item 1\nNew line 1\nNew line 2",
                        .text = "Item 1",
                        .layout = .{ .alignment = tuile.Align.topLeft() },
                    }),
                    .value = null,
                },
                .{
                    .label = try tuile.label(.{
                        .text = "Item 2 - long line long line long line",
                        .layout = .{ .alignment = tuile.Align.topLeft() },
                    }),
                    .value = null,
                },
                .{
                    .label = try tuile.label(.{
                        .text = "Item 3",
                        .layout = .{ .alignment = tuile.Align.topLeft() },
                    }),
                    .value = null,
                },
                .{
                    .label = try tuile.label(.{
                        .text = "Item 4",
                        .layout = .{ .alignment = tuile.Align.topLeft() },
                    }),
                    .value = null,
                },
                .{
                    .label = try tuile.label(.{
                        .text = "Item 5",
                        .layout = .{ .alignment = tuile.Align.topLeft() },
                    }),
                    .value = null,
                },
                .{
                    .label = try tuile.label(.{
                        .text = "Item 6",
                        .layout = .{ .alignment = tuile.Align.topLeft() },
                    }),
                    .value = null,
                },
            },
        ),
    );

    try tui.add(layout);
    try tui.run();
}
