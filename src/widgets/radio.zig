const std = @import("std");
const Widget = @import("Widget.zig");
const Vec2 = @import("../Vec2.zig");
const events = @import("../events.zig");
const Painter = @import("../Painter.zig");

const Config = struct {
    options: []const []const u8,

    selected: ?usize = null,
};

pub fn Radio(comptime config: Config) type {
    return struct {
        const Self = @This();

        const Marker = struct {
            const Selected = "[x] ";
            const Basic = "[ ] ";
        };

        allocator: std.mem.Allocator,

        options: []const []const u8,

        bounds: ?Vec2 = null,

        selected: ?usize,

        focused: ?usize = null,

        pub fn create(allocator: std.mem.Allocator) !*Self {
            var options = try std.ArrayList([]const u8).initCapacity(allocator, config.options.len);
            for (config.options) |option| {
                try options.append(try allocator.dupe(u8, option));
            }

            const self = try allocator.create(Self);
            self.* = Self{
                .allocator = allocator,
                .options = try options.toOwnedSlice(),
                .selected = config.selected,
            };
            return self;
        }

        pub fn destroy(self: *Self) void {
            for (self.options) |option| {
                self.allocator.free(option);
            }
            self.allocator.free(self.options);
            self.allocator.destroy(self);
        }

        pub fn widget(self: *Self) Widget {
            return Widget.init(self);
        }

        pub fn draw(self: *Self, painter: *Painter) !void {
            const rows = if (self.bounds) |bounds| bounds.y else self.options.len;
            var cursor = painter.cursor;

            for (self.options[0..rows], 0..) |option, idx| {
                painter.move_to(cursor);

                const marker = if (idx == self.selected) Marker.Selected else Marker.Basic;
                const desired_len = marker.len + option.len;

                const len = if (self.bounds) |bounds|
                    @min(bounds.x, desired_len)
                else
                    desired_len;

                if (len <= marker.len) {
                    // Only marker is visible
                    try painter.print(marker[0..len]);
                } else {
                    try painter.print(marker);
                    try painter.print(option[0..@min(option.len, len - marker.len)]);
                }

                cursor.y += 1;
            }
        }

        pub fn desired_size(self: *Self, _: Vec2) !Vec2 {
            const y = self.options.len;
            var x: usize = 0;
            for (self.options) |option| {
                x = @max(x, option.len + Marker.Basic.len);
            }
            return .{ .x = @intCast(x), .y = @intCast(y) };
        }

        pub fn layout(self: *Self, bounds: Vec2) !void {
            self.bounds = bounds;
        }

        pub fn handle_event(self: *Self, event: events.Event) !events.EventResult {
            switch (event) {
                .Key, .ShiftKey => {
                    if (self.focused) |focused| {
                        const new_focused = if (event == .Key) focused + 1 else focused -% 1;
                        if (new_focused < self.options.len) {
                            self.focused = new_focused;
                            return .Consumed;
                        }
                    } else {
                        self.focused = 0;
                        return .Consumed;
                    }
                },
                .Char => |char| switch (char) {
                    ' ' => {
                        self.selected = self.focused;
                        return .Consumed;
                    },
                    else => {},
                },
                else => {},
            }
            return .Ignored;
        }

        pub fn focus(_: *Self) !events.EventResult {
            return .Consumed;
        }
    };
}