const std = @import("std");
const Widget = @import("Widget.zig");
const Vec2 = @import("../Vec2.zig");
const Rect = @import("../Rect.zig");
const events = @import("../events.zig");
const Frame = @import("../render/Frame.zig");
const border = @import("../border.zig");
const Padding = @import("Padding.zig");
const Sized = @import("Sized.zig");
const Constraints = @import("Constraints.zig");

pub fn Block(comptime Inner: anytype) type {
    return struct {
        const Self = @This();

        pub const Config = struct {
            border: border.Border = border.Border.none(),

            border_type: border.BorderType = .solid,

            padding: Padding = .{},

            sized: Sized = .{},
        };

        allocator: std.mem.Allocator,

        inner: *Inner,

        border: border.Border,

        border_chars: border.BorderCharacters,

        border_widths: Padding,

        sized: Sized,

        pub fn create(allocator: std.mem.Allocator, config: Config, inner: *Inner) !*Self {
            const border_chars = border.BorderCharacters.from_type(config.border_type);

            const self = try allocator.create(Self);
            self.* = Self{
                .allocator = allocator,
                .inner = inner,
                .border = config.border,
                .border_chars = border_chars,
                .border_widths = .{
                    .top = @intFromBool(config.border.top) + config.padding.top,
                    .bottom = @intFromBool(config.border.bottom) + config.padding.bottom,
                    .left = @intFromBool(config.border.left) + config.padding.left,
                    .right = @intFromBool(config.border.right) + config.padding.right,
                },
                .sized = config.sized,
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

        pub fn render(self: *Self, area: Rect, frame: *Frame) !void {
            const inner_area = .{
                .min = area.min.add(.{
                    .x = self.border_widths.left,
                    .y = self.border_widths.top,
                }),
                .max = area.max.sub(.{
                    .x = self.border_widths.right,
                    .y = self.border_widths.bottom,
                }),
            };

            if (inner_area.min.x > inner_area.max.x or inner_area.min.y > inner_area.max.y) {
                try self.inner.render(area, frame);
            } else {
                try self.inner.render(inner_area, frame);
                self.render_border(area, frame);
            }
        }

        pub fn desired_size(self: *Self, available: Vec2) !Vec2 {
            const inner_size = try self.inner.desired_size(available);
            return inner_size.add(.{
                .x = self.border_widths.left + self.border_widths.right,
                .y = self.border_widths.top + self.border_widths.bottom,
            });
        }

        pub fn layout(self: *Self, constraints: Constraints) !void {
            try self.inner.layout(.{
                .min_width = constraints.min_width,
                .min_height = constraints.min_height,
                .max_width = constraints.max_width -| (self.border_widths.left + self.border_widths.right),
                .max_height = constraints.max_height -| (self.border_widths.top + self.border_widths.bottom),
            });
        }

        pub fn handle_event(self: *Self, event: events.Event) !events.EventResult {
            return self.inner.handle_event(event);
        }

        fn render_border(self: *Self, area: Rect, frame: *Frame) void {
            var x = area.min.x;
            while (x < area.max.x) : (x += 1) {
                if (self.border.top)
                    frame.at(.{ .x = x, .y = area.min.y }).symbol = self.border_chars.top;
                if (self.border.bottom)
                    frame.at(.{ .x = x, .y = area.max.y - 1 }).symbol = self.border_chars.bottom;
            }

            var y = area.min.y;
            while (y < area.max.y) : (y += 1) {
                if (self.border.left)
                    frame.at(.{ .x = area.min.x, .y = y }).symbol = self.border_chars.left;
                if (self.border.right)
                    frame.at(.{ .x = area.max.x - 1, .y = y }).symbol = self.border_chars.right;
            }

            if (self.border.top and self.border.left)
                frame.at(.{ .x = area.min.x, .y = area.min.y }).symbol = self.border_chars.top_left;

            if (self.border.top and self.border.right)
                frame.at(.{ .x = area.max.x - 1, .y = area.min.y }).symbol = self.border_chars.top_right;

            if (self.border.bottom and self.border.left)
                frame.at(.{ .x = area.min.x, .y = area.max.y - 1 }).symbol = self.border_chars.bottom_left;

            if (self.border.bottom and self.border.right)
                frame.at(.{ .x = area.max.x - 1, .y = area.max.y - 1 }).symbol = self.border_chars.bottom_right;
        }
    };
}
