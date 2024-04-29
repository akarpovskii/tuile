const std = @import("std");
const tuile = @import("tuile");

const ListApp = struct {
    input: ?[]const u8 = null,

    tui: *tuile.Tuile,

    pub fn onPress(opt_self: ?*ListApp) void {
        const self = opt_self.?;
        if (self.input) |input| {
            if (input.len > 0) {
                const list = self.tui.findByIdTyped(tuile.StackLayout, "list-id") orelse unreachable;
                list.addChild(tuile.label(.{ .text = input })) catch unreachable;
            }
        }
    }

    pub fn inputChanged(opt_self: ?*ListApp, value: []const u8) void {
        const self = opt_self.?;
        self.input = value;
    }
};

pub fn main() !void {
    var tui = try tuile.Tuile.init(.{});
    defer tui.deinit();

    var list_app = ListApp{ .tui = &tui };

    const layout = tuile.vertical(
        .{ .layout = .{ .flex = 1 } },
        .{
            tuile.block(
                .{ .border = tuile.border.Border.all(), .layout = .{ .flex = 1 } },
                tuile.vertical(
                    .{ .id = "list-id" },
                    .{},
                ),
            ),

            tuile.horizontal(
                .{},
                .{
                    tuile.input(.{
                        .layout = .{ .flex = 1 },
                        .on_value_changed = .{
                            .cb = @ptrCast(&ListApp.inputChanged),
                            .payload = &list_app,
                        },
                    }),
                    tuile.button(.{
                        .text = "Submit",
                        .on_press = .{
                            .cb = @ptrCast(&ListApp.onPress),
                            .payload = &list_app,
                        },
                    }),
                },
            ),
        },
    );

    try tui.add(layout);

    try tui.run();
}
