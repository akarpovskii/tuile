const std = @import("std");
const tuile = @import("tuile");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const tuile_allocator = gpa.allocator();

pub fn main() !void {
    defer _ = gpa.deinit();

    var tui = try tuile.Tuile.init();
    defer tui.deinit();

    var multiline_span = tuile.Span.init(tuile_allocator);
    defer multiline_span.deinit();
    try multiline_span.append(.{ .text = "Multiline\n", .style = .{ .fg = .{ .bright = .red } } });
    try multiline_span.append(.{ .text = "text", .style = .{ .fg = .{ .bright = .blue } } });

    const layout = tuile.vertical(
        .{ .layout = .{ .flex = 1 } },
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
            tuile.horizontal(
                .{},
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
                tuile.label(.{ .span = multiline_span.view() }),
            ),
            tuile.block(
                .{
                    .border = tuile.border.Border.none(),
                    .padding = .{ .top = 1, .bottom = 1, .left = 1, .right = 1 },
                },
                tuile.label(.{ .text = "Padding\nwithout borders" }),
            ),
            tuile.horizontal(
                .{},
                .{
                    tuile.button(.{ .text = "Button 1" }),
                    tuile.button(.{ .text = "Button 2" }),
                },
            ),

            tuile.horizontal(
                .{},
                .{
                    tuile.spacer(.{}),
                    tuile.block(
                        .{ .border = tuile.border.Border.all(), .border_type = .double },
                        tuile.checkbox_group(
                            .{ .multiselect = false },
                            .{
                                tuile.checkbox(.{ .text = "Option 1" }),
                                tuile.checkbox(.{ .text = "Option 2" }),
                                tuile.checkbox(.{ .text = "Option 3" }),
                            },
                        ),
                    ),
                    tuile.spacer(.{ .layout = .{ .max_width = 10, .max_height = 1 } }),
                    tuile.block(
                        .{ .border = tuile.border.Border.all(), .border_type = .double },
                        tuile.checkbox_group(
                            .{ .multiselect = true },
                            .{
                                tuile.checkbox(.{ .text = "Option 1" }),
                                tuile.checkbox(.{ .text = "Option 2" }),
                                tuile.checkbox(.{ .text = "Option 3" }),
                            },
                        ),
                    ),
                    tuile.spacer(.{}),
                },
            ),
            tuile.horizontal(
                .{},
                .{
                    tuile.input(.{ .placeholder = "placeholder", .layout = .{ .flex = 1 } }),
                    tuile.button(.{ .text = "Submit" }),
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
