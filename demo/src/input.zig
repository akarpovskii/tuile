const std = @import("std");
const tuile = @import("tuile");

const ListState = struct {
    allocator: std.mem.Allocator,

    items: std.ArrayList([]const u8),

    input: ?[]const u8 = null,

    change_notifier: tuile.ChangeNotifier,
    pub usingnamespace tuile.ChangeNotifier.Mixin(@This(), .change_notifier);

    pub fn init(allocator: std.mem.Allocator) ListState {
        return ListState{
            .allocator = allocator,
            .items = std.ArrayList([]const u8).init(allocator),
            .change_notifier = tuile.ChangeNotifier.init(),
        };
    }

    pub fn deinit(self: *ListState) void {
        for (self.items.items) |item| {
            self.allocator.free(item);
        }
        self.change_notifier.deinit();
        self.items.deinit();
    }

    pub fn onPress(ptr: ?*anyopaque) void {
        const self: *ListState = @ptrCast(@alignCast(ptr.?));
        if (self.input) |input| {
            if (input.len > 0) {
                self.items.append(self.allocator.dupe(u8, input) catch @panic("OOM")) catch @panic("OOM");
                self.notifyListeners();
            }
        }
    }

    pub fn inputChanged(ptr: ?*anyopaque, value: []const u8) void {
        const self: *ListState = @ptrCast(@alignCast(ptr.?));
        self.input = value;
    }
};

const ListView = struct {
    allocator: std.mem.Allocator,

    pub fn build(self: *ListView, context: *tuile.StatefulWidget.BuildContext) !tuile.Widget {
        const state: *ListState = try context.watch(ListState);

        var lines = try std.ArrayList(*tuile.Label).initCapacity(self.allocator, state.items.items.len);
        defer lines.deinit();
        for (state.items.items) |item| {
            lines.append(try tuile.label(.{ .text = item })) catch unreachable;
        }

        const widget = try tuile.block(
            .{ .border = tuile.border.Border.all(), .layout = .{ .flex = 1 } },
            try tuile.stack_layout(
                .{ .orientation = .vertical },
                lines.items,
            ),
        );

        return widget.widget();
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var tui = try tuile.Tuile.init();
    defer tui.deinit();

    var list_state = ListState.init(allocator);
    defer list_state.deinit();

    var list_view = ListView{ .allocator = allocator };

    const layout = tuile.stack_layout(
        .{ .orientation = .vertical, .layout = .{ .flex = 1 } },
        .{
            tuile.stateful(&list_view, &list_state),

            tuile.stack_layout(
                .{ .orientation = .horizontal },
                .{
                    tuile.input(.{
                        .layout = .{ .flex = 1 },
                        .on_value_changed = .{
                            .cb = ListState.inputChanged,
                            .payload = &list_state,
                        },
                    }),
                    tuile.button(.{
                        .label = "Submit",
                        .on_press = .{
                            .cb = ListState.onPress,
                            .payload = &list_state,
                        },
                    }),
                },
            ),
        },
    );

    try tui.add(layout);

    try tui.run();
}
