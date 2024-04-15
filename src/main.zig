const std = @import("std");
const dotenv = @import("dotenv.zig");

const tuile = @import("tuile.zig");
const widgets = tuile.widgets;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var env = try dotenv.load(allocator);
    defer env.deinit();

    var tui = try tuile.Tuile.init(allocator);
    defer {
        tui.deinit() catch {
            std.debug.print("Failed to deinit ncurses", .{});
        };
    }

    const layout = try widgets.StackLayout(
        .{ .orientation = .Vertical },
        .{
            widgets.StyledWidget(.{}, widgets.Label(.{ .text = "Label text 1" })),
            widgets.Label(.{ .text = "Label text 2" }),
            widgets.Label(.{ .text = "Label text 3" }),
            widgets.StackLayout(
                .{ .orientation = .Horizontal },
                .{
                    widgets.StyledWidget(.{}, widgets.Label(.{ .text = "Label text 4 aaaaaa" })),
                    widgets.Label(.{ .text = "Label text 5" }),
                },
            ),
            widgets.Label(.{ .text = "Label text 6" }),
            widgets.Label(.{ .text = "Label text 7" }),
            widgets.StyledWidget(.{}, widgets.Radio(.{ .options = &.{ "Option 1", "Option 2", "Option 3" } })),
        },
    ).create(allocator);

    try tui.add(layout.widget());

    try tui.run();
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
