const std = @import("std");
const tuile = @import("tuile");
const widgets = tuile.widgets;
const Align = widgets.LayoutProperties.Align;

const ListView = struct {
    allocator: std.mem.Allocator,

    items: std.ArrayList([]const u8),

    input: ?[]const u8 = null,

    need_rebuild: bool = false,

    pub fn init(allocator: std.mem.Allocator) ListView {
        return ListView{
            .allocator = allocator,
            .items = std.ArrayList([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *ListView) void {
        for (self.items.items) |item| {
            self.allocator.free(item);
        }
        self.items.deinit();
    }

    pub fn build(self: *ListView) !widgets.Widget {
        var lines = try std.ArrayList(*widgets.Label).initCapacity(self.allocator, self.items.items.len);
        defer lines.deinit();
        for (self.items.items) |item| {
            lines.append(try widgets.Label.create(self.allocator, .{ .text = item })) catch unreachable;
        }

        const widget = try widgets.Block.create(
            self.allocator,
            .{ .border = widgets.border.Border.all(), .layout = .{ .flex = 1 } },
            try widgets.StackLayout.create(
                self.allocator,
                .{ .orientation = .vertical },
                lines.items,
            ),
        );

        self.need_rebuild = false;

        return widget.widget();
    }

    pub fn needRebuild(self: *ListView) bool {
        return self.need_rebuild;
    }

    pub fn onPress(ptr: ?*anyopaque) void {
        const self: *ListView = @ptrCast(@alignCast(ptr.?));
        if (self.input) |input| {
            if (input.len > 0) {
                self.items.append(self.allocator.dupe(u8, input) catch @panic("OOM")) catch @panic("OOM");
                self.need_rebuild = true;
            }
        }
    }

    pub fn inputChanged(ptr: ?*anyopaque, value: []const u8) void {
        const self: *ListView = @ptrCast(@alignCast(ptr.?));
        self.input = value;
    }
};

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

    var list_view = ListView.init(allocator);
    defer list_view.deinit();

    const layout = try widgets.StackLayout.create(
        allocator,
        .{ .orientation = .vertical, .layout = .{ .flex = 1 } },
        .{
            try widgets.StatefulWidget.create(
                allocator,
                &list_view,
            ),

            try widgets.StackLayout.create(
                allocator,
                .{ .orientation = .horizontal },
                .{
                    try widgets.Input.create(allocator, .{
                        .layout = .{ .flex = 1 },
                        .on_value_changed = .{
                            .cb = ListView.inputChanged,
                            .payload = &list_view,
                        },
                    }),
                    try widgets.Button.create(allocator, .{
                        .label = "Submit",
                        .on_press = .{
                            .cb = ListView.onPress,
                            .payload = &list_view,
                        },
                    }),
                },
            ),
        },
    );

    try tui.add(layout.widget());

    try tui.run();
}
