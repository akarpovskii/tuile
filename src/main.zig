const std = @import("std");

const tuile = @import("tuile.zig");
const widgets = tuile.widgets;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var tui = try tuile.Tuile.init(allocator);
    defer {
        tui.deinit() catch {
            std.debug.print("Failed to deinit ncurses", .{});
        };
    }

    const layout = try widgets.StackLayout.create(
        allocator,
        .{ .orientation = .vertical, .layout = .{ .flex = 1 } },
        .{
            try widgets.Block(widgets.Label).create(
                allocator,
                .{ .border = tuile.border.Border.all(), .layout = .{ .flex = 1 } },
                try widgets.Label.create(allocator, .{ .text = "Label text 1" }),
            ),
            try widgets.Label.create(allocator, .{ .text = "Label text 2" }),
            try widgets.Label.create(allocator, .{ .text = "Label text 3" }),
            try widgets.StackLayout.create(
                allocator,
                .{ .orientation = .horizontal },
                .{
                    try widgets.Block(widgets.Label).create(
                        allocator,
                        .{ .border = tuile.border.Border.all(), .border_type = .rounded },
                        try widgets.Label.create(allocator, .{ .text = "Label text 4 aaaaaa" }),
                    ),
                    try widgets.Label.create(allocator, .{ .text = "Label text 5" }),
                },
            ),
            try widgets.Block(widgets.Label).create(
                allocator,
                .{
                    .border = tuile.border.Border.all(),
                    .border_type = .rounded,
                    .padding = .{ .top = 1, .bottom = 2, .left = 3, .right = 0 },
                },
                try widgets.Label.create(allocator, .{ .text = "Multiline\nlabel text" }),
            ),
            try widgets.Block(widgets.Label).create(
                allocator,
                .{
                    .border = tuile.border.Border.none(),
                    .padding = .{ .top = 1, .bottom = 1, .left = 1, .right = 1 },
                },
                try widgets.Label.create(allocator, .{ .text = "Padding\nwithout borders" }),
            ),
            try widgets.StackLayout.create(
                allocator,
                .{ .orientation = .horizontal },
                .{
                    try widgets.Button.create(allocator, .{ .label = "Button 1", .on_press = handle_press }),
                    try widgets.Button.create(allocator, .{ .label = "Button 2", .on_press = handle_press }),
                },
            ),

            try widgets.StackLayout.create(
                allocator,
                .{ .orientation = .horizontal },
                .{
                    try widgets.Spacer.create(allocator, .{}),
                    try widgets.Block(widgets.CheckboxGroup).create(
                        allocator,
                        .{ .border = tuile.border.Border.all(), .border_type = .double },
                        try widgets.CheckboxGroup.create(
                            allocator,
                            .{ .multiselect = false },
                            .{
                                try widgets.Checkbox.create(allocator, .{ .label = "Option 1" }),
                                try widgets.Checkbox.create(allocator, .{ .label = "Option 2" }),
                                try widgets.Checkbox.create(allocator, .{ .label = "Option 3" }),
                            },
                        ),
                    ),
                    try widgets.Spacer.create(allocator, .{ .layout = .{ .max_width = 10, .max_height = 1 } }),
                    try widgets.Block(widgets.CheckboxGroup).create(
                        allocator,
                        .{ .border = tuile.border.Border.all(), .border_type = .double },
                        try widgets.CheckboxGroup.create(
                            allocator,
                            .{ .multiselect = true },
                            .{
                                try widgets.Checkbox.create(allocator, .{ .label = "Option 1" }),
                                try widgets.Checkbox.create(allocator, .{ .label = "Option 2" }),
                                try widgets.Checkbox.create(allocator, .{ .label = "Option 3" }),
                            },
                        ),
                    ),
                    try widgets.Spacer.create(allocator, .{}),
                },
            ),
            try widgets.StackLayout.create(
                allocator,
                .{ .orientation = .horizontal },
                .{
                    try widgets.Input.create(allocator, .{ .placeholder = "placeholder", .layout = .{ .flex = 1 } }),
                    try widgets.Button.create(allocator, .{ .label = "Submit" }),
                },
            ),
        },
    );

    try tui.add(layout.widget());

    try tui.run();
}

fn handle_press(label: []const u8) void {
    std.debug.print("\tPressed {s}", .{label});
}
