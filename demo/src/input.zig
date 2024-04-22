const std = @import("std");
const tuile = @import("tuile");
const widgets = tuile.widgets;
const Align = widgets.LayoutProperties.Align;

const ListState = struct {
    allocator: std.mem.Allocator,

    items: std.ArrayList([]const u8),

    input: ?[]const u8 = null,

    change_notifier: widgets.ChangeNotifier,
    pub usingnamespace widgets.ChangeNotifier.Mixin(@This(), .change_notifier);

    pub fn init(allocator: std.mem.Allocator) ListState {
        return ListState{
            .allocator = allocator,
            .items = std.ArrayList([]const u8).init(allocator),
            .change_notifier = widgets.ChangeNotifier.init(),
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

    pub fn build(self: *ListView, context: *widgets.StatefulWidget.BuildContext) !widgets.Widget {
        const state: *ListState = try context.watch(ListState);

        var lines = try std.ArrayList(*widgets.Label).initCapacity(self.allocator, state.items.items.len);
        defer lines.deinit();
        for (state.items.items) |item| {
            lines.append(try widgets.Label.create(.{ .text = item })) catch unreachable;
        }

        const widget = try widgets.Block.create(
            .{ .border = widgets.border.Border.all(), .layout = .{ .flex = 1 } },
            try widgets.StackLayout.create(
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
    defer {
        tui.deinit() catch {
            std.debug.print("Failed to deinit ncurses", .{});
        };
    }

    var list_state = ListState.init(allocator);
    defer list_state.deinit();

    var list_view = ListView{ .allocator = allocator };

    const layout = try widgets.StackLayout.create(
        .{ .orientation = .vertical, .layout = .{ .flex = 1 } },
        .{
            try widgets.StatefulWidget.create(
                &list_view,
                &list_state,
            ),

            try widgets.StackLayout.create(
                .{ .orientation = .horizontal },
                .{
                    try widgets.Input.create(.{
                        .layout = .{ .flex = 1 },
                        .on_value_changed = .{
                            .cb = ListState.inputChanged,
                            .payload = &list_state,
                        },
                    }),
                    try widgets.Button.create(.{
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

    try tui.add(layout.widget());

    try tui.run();
}
