const std = @import("std");
const Widget = @import("Widget.zig");
const Vec2 = @import("../Vec2.zig");
const events = @import("../events.zig");
const Painter = @import("../Painter.zig");
const border = @import("../border.zig");

pub fn Block(comptime Inner: anytype) type {
    return struct {
        const Self = @This();

        pub const Config = struct {
            border: border.Border = border.Border.none(),

            border_type: border.BorderType = .solid,
        };

        allocator: std.mem.Allocator,

        inner: *Inner,

        border: border.Border,

        border_chars: border.BorderCharacters,

        size: ?Vec2 = null,

        border_widths: struct { top: u32, bottom: u32, left: u32, right: u32 },

        pub fn create(allocator: std.mem.Allocator, config: Config, inner: *Inner) !*Self {
            const border_chars = border.BorderCharacters.from_type(config.border_type);

            const self = try allocator.create(Self);
            self.* = Self{
                .allocator = allocator,
                .inner = inner,
                .border = config.border,
                .border_chars = border_chars,
                .border_widths = .{
                    .top = @intFromBool(config.border.top),
                    .bottom = @intFromBool(config.border.bottom),
                    .left = @intFromBool(config.border.left),
                    .right = @intFromBool(config.border.right),
                },
            };
            return self;
        }

        pub fn destroy(self: *Self) void {
            self.inner.destroy();
            self.allocator.destroy(self);
        }

        pub fn widget(self: *Self) Widget {
            return Widget.init(self);
        }

        pub fn draw(self: *Self, painter: *Painter) !void {
            const min = painter.cursor;
            const max = min.add(self.size.?).sub(.{ .x = 1, .y = 1 });

            painter.offset(.{
                .x = self.border_widths.left,
                .y = self.border_widths.top,
            });
            try self.inner.draw(painter);

            try self.print_border(painter, min, max);

            painter.move_to(max);
        }

        pub fn desired_size(self: *Self, available: Vec2) !Vec2 {
            const inner_size = try self.inner.desired_size(available);
            return inner_size.add(.{
                .x = self.border_widths.left + self.border_widths.right,
                .y = self.border_widths.top + self.border_widths.bottom,
            });
        }

        pub fn layout(self: *Self, bounds: Vec2) !void {
            self.size = bounds;
            const inner_bounds = .{
                .x = bounds.x -| (self.border_widths.left + self.border_widths.right),
                .y = bounds.y -| (self.border_widths.top + self.border_widths.bottom),
            };
            try self.inner.layout(inner_bounds);
        }

        pub fn handle_event(self: *Self, event: events.Event) !events.EventResult {
            return self.inner.handle_event(event);
        }

        pub fn print_border(self: *Self, painter: *Painter, top_left: Vec2, bottom_right: Vec2) !void {
            var x = top_left.x;
            while (x <= bottom_right.x) : (x += 1) {
                if (self.border.top)
                    try painter.print_at(.{ .x = x, .y = top_left.y }, self.border_chars.top);
                if (self.border.bottom)
                    try painter.print_at(.{ .x = x, .y = bottom_right.y }, self.border_chars.bottom);
            }

            var y = top_left.y;
            while (y <= bottom_right.y) : (y += 1) {
                if (self.border.left)
                    try painter.print_at(.{ .x = top_left.x, .y = y }, self.border_chars.left);
                if (self.border.right)
                    try painter.print_at(.{ .x = bottom_right.x, .y = y }, self.border_chars.right);
            }

            if (self.border.top and self.border.left)
                try painter.print_at(.{ .x = top_left.x, .y = top_left.y }, self.border_chars.top_left);

            if (self.border.top and self.border.right)
                try painter.print_at(.{ .x = bottom_right.x, .y = top_left.y }, self.border_chars.top_right);

            if (self.border.bottom and self.border.left)
                try painter.print_at(.{ .x = top_left.x, .y = bottom_right.y }, self.border_chars.bottom_left);

            if (self.border.bottom and self.border.right)
                try painter.print_at(.{ .x = bottom_right.x, .y = bottom_right.y }, self.border_chars.bottom_right);
        }
    };
}
