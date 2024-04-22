const std = @import("std");
const tuile = @import("tuile");
const widgets = tuile.widgets;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const tuile_allocator = gpa.allocator();

pub fn main() !void {
    defer _ = gpa.deinit();

    var tui = try tuile.Tuile.init();
    defer {
        tui.deinit() catch {
            std.debug.print("Failed to deinit ncurses", .{});
        };
    }

    const layout = try widgets.StackLayout.create(
        .{ .orientation = .vertical, .layout = .{ .flex = 1 } },
        .{
            widgets.Themed.create(
                .{ .theme = .{
                    .background = .{ .rgb = tuile.color.Rgb.blue() },
                    .foreground = .{ .rgb = tuile.color.Rgb.white() },
                } },
                widgets.Themed.create(
                    .{ .theme = .{
                        .background = .{ .bright = .yellow },
                    } },
                    widgets.Block.create(
                        .{ .border = widgets.border.Border.all(), .layout = .{ .flex = 1 } },
                        widgets.Label.create(.{ .text = "Label text 1" }),
                    ),
                ),
            ),
            widgets.Label.create(.{ .text = "Label text 2" }),
            widgets.Label.create(.{ .text = "Label text 3" }),
            widgets.StackLayout.create(
                .{ .orientation = .horizontal },
                .{
                    widgets.Block.create(
                        .{ .border = widgets.border.Border.all(), .border_type = .rounded },
                        widgets.Label.create(.{ .text = "Label text 4 aaaaaa" }),
                    ),
                    widgets.Label.create(.{ .text = "Label text 5" }),
                },
            ),
            widgets.Block.create(
                .{
                    .border = widgets.border.Border.all(),
                    .border_type = .rounded,
                    .padding = .{ .top = 1, .bottom = 2, .left = 3, .right = 0 },
                },
                widgets.Label.create(.{ .text = "Multiline\nlabel text" }),
            ),
            widgets.Block.create(
                .{
                    .border = widgets.border.Border.none(),
                    .padding = .{ .top = 1, .bottom = 1, .left = 1, .right = 1 },
                },
                widgets.Label.create(.{ .text = "Padding\nwithout borders" }),
            ),
            widgets.StackLayout.create(
                .{ .orientation = .horizontal },
                .{
                    widgets.Button.create(.{ .label = "Button 1" }),
                    widgets.Button.create(.{ .label = "Button 2" }),
                },
            ),

            widgets.StackLayout.create(
                .{ .orientation = .horizontal },
                .{
                    widgets.Spacer.create(.{}),
                    widgets.Block.create(
                        .{ .border = widgets.border.Border.all(), .border_type = .double },
                        widgets.CheckboxGroup.create(
                            .{ .multiselect = false },
                            .{
                                widgets.Checkbox.create(.{ .label = "Option 1" }),
                                widgets.Checkbox.create(.{ .label = "Option 2" }),
                                widgets.Checkbox.create(.{ .label = "Option 3" }),
                            },
                        ),
                    ),
                    widgets.Spacer.create(.{ .layout = .{ .max_width = 10, .max_height = 1 } }),
                    widgets.Block.create(
                        .{ .border = widgets.border.Border.all(), .border_type = .double },
                        widgets.CheckboxGroup.create(
                            .{ .multiselect = true },
                            .{
                                widgets.Checkbox.create(.{ .label = "Option 1" }),
                                widgets.Checkbox.create(.{ .label = "Option 2" }),
                                widgets.Checkbox.create(.{ .label = "Option 3" }),
                            },
                        ),
                    ),
                    widgets.Spacer.create(.{}),
                },
            ),
            widgets.StackLayout.create(
                .{ .orientation = .horizontal },
                .{
                    widgets.Input.create(.{ .placeholder = "placeholder", .layout = .{ .flex = 1 } }),
                    widgets.Button.create(.{ .label = "Submit" }),
                },
            ),
        },
    );

    try tui.add(layout.widget());

    try tui.run();
}

fn handlePress(label: []const u8) void {
    std.debug.print("\tPressed {s}", .{label});
}
