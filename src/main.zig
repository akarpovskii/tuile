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
        .{ .orientation = .Vertical },
        .{
            try widgets.Block(widgets.Label).create(
                allocator,
                .{ .border = tuile.border.Border.all() },
                try widgets.Label.create(allocator, .{ .text = "Label text 1" }),
            ),
            try widgets.Label.create(allocator, .{ .text = "Label text 2" }),
            try widgets.Label.create(allocator, .{ .text = "Label text 3" }),
            try widgets.StackLayout.create(
                allocator,
                .{ .orientation = .Horizontal },
                .{
                    try widgets.Block(widgets.Label).create(
                        allocator,
                        .{ .border = tuile.border.Border.all(), .border_type = .rounded },
                        try widgets.Label.create(allocator, .{ .text = "Label text 4 aaaaaa" }),
                    ),
                    try widgets.Label.create(allocator, .{ .text = "Label text 5" }),
                },
            ),
            try widgets.Label.create(allocator, .{ .text = "Label text 6" }),
            try widgets.Label.create(allocator, .{ .text = "Label text 7" }),
            try widgets.StackLayout.create(
                allocator,
                .{ .orientation = .Horizontal },
                .{
                    try widgets.Button.create(allocator, .{ .label = "Button 1", .on_press = handle_press }),
                    try widgets.Button.create(allocator, .{ .label = "Button 2", .on_press = handle_press }),
                },
            ),

            try widgets.StackLayout.create(
                allocator,
                .{ .orientation = .Horizontal },
                .{
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
                },
            ),
            try widgets.Input.create(allocator, .{ .placeholder = "placeholder" }),
        },
    );

    try tui.add(layout.widget());

    try tui.run();
}

fn handle_press(label: []const u8) void {
    std.debug.print("\tPressed {s}", .{label});
}
