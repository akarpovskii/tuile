const std = @import("std");
const tuile = @import("tuile");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const tuile_allocator = gpa.allocator();

pub fn main() !void {
    defer _ = gpa.deinit();

    var tui = try tuile.Tuile.init();
    defer tui.deinit();

    const layout = tuile.stack_layout(
        .{ .orientation = .vertical, .layout = .{ .flex = 1 } },
        .{
            tuile.themed(
                .{ .theme = .{
                    .background = .{ .rgb = tuile.color.Rgb.blue() },
                    .foreground = .{ .rgb = tuile.color.Rgb.white() },
                } },
                tuile.themed(
                    .{ .theme = .{
                        .background = .{ .bright = .yellow },
                    } },
                    tuile.block(
                        .{ .border = tuile.border.Border.all(), .layout = .{ .flex = 1 } },
                        tuile.label(.{ .text = "Label text 1" }),
                    ),
                ),
            ),
            tuile.label(.{ .text = "Label text 2" }),
            tuile.label(.{ .text = "Label text 3" }),
            tuile.stack_layout(
                .{ .orientation = .horizontal },
                .{
                    tuile.block(
                        .{ .border = tuile.border.Border.all(), .border_type = .rounded },
                        tuile.label(.{ .text = "Label text 4 aaaaaa" }),
                    ),
                    tuile.label(.{ .text = "Label text 5" }),
                },
            ),
            tuile.block(
                .{
                    .border = tuile.border.Border.all(),
                    .border_type = .rounded,
                    .padding = .{ .top = 1, .bottom = 2, .left = 3, .right = 0 },
                },
                tuile.label(.{ .text = "Multiline\nlabel text" }),
            ),
            tuile.block(
                .{
                    .border = tuile.border.Border.none(),
                    .padding = .{ .top = 1, .bottom = 1, .left = 1, .right = 1 },
                },
                tuile.label(.{ .text = "Padding\nwithout borders" }),
            ),
            tuile.stack_layout(
                .{ .orientation = .horizontal },
                .{
                    tuile.button(.{ .label = "Button 1" }),
                    tuile.button(.{ .label = "Button 2" }),
                },
            ),

            tuile.stack_layout(
                .{ .orientation = .horizontal },
                .{
                    tuile.spacer(.{}),
                    tuile.block(
                        .{ .border = tuile.border.Border.all(), .border_type = .double },
                        tuile.checkbox_group(
                            .{ .multiselect = false },
                            .{
                                tuile.checkbox(.{ .label = "Option 1" }),
                                tuile.checkbox(.{ .label = "Option 2" }),
                                tuile.checkbox(.{ .label = "Option 3" }),
                            },
                        ),
                    ),
                    tuile.spacer(.{ .layout = .{ .max_width = 10, .max_height = 1 } }),
                    tuile.block(
                        .{ .border = tuile.border.Border.all(), .border_type = .double },
                        tuile.checkbox_group(
                            .{ .multiselect = true },
                            .{
                                tuile.checkbox(.{ .label = "Option 1" }),
                                tuile.checkbox(.{ .label = "Option 2" }),
                                tuile.checkbox(.{ .label = "Option 3" }),
                            },
                        ),
                    ),
                    tuile.spacer(.{}),
                },
            ),
            tuile.stack_layout(
                .{ .orientation = .horizontal },
                .{
                    tuile.input(.{ .placeholder = "placeholder", .layout = .{ .flex = 1 } }),
                    tuile.button(.{ .label = "Submit" }),
                },
            ),
        },
    );

    try tui.add(layout);

    try tui.run();
}

fn handlePress(label: []const u8) void {
    std.debug.print("\tPressed {s}", .{label});
}
