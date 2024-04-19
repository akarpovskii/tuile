const std = @import("std");
const Widget = @import("Widget.zig");
const Vec2 = @import("../Vec2.zig");
const Rect = @import("../Rect.zig");
const events = @import("../events.zig");
const Frame = @import("../render/Frame.zig");
const border = @import("../border.zig");
const Padding = @import("Padding.zig");
const LayoutProperties = @import("LayoutProperties.zig");
const Constraints = @import("Constraints.zig");

pub fn Block(comptime Inner: anytype) type {
    return struct {
        const Self = @This();

        pub const Config = struct {
            border: border.Border = border.Border.none(),

            border_type: border.BorderType = .solid,

            padding: Padding = .{},

            fit_content: bool = false,

            layout: LayoutProperties = .{},
        };

        allocator: std.mem.Allocator,

        inner: *Inner,

        border: border.Border,

        border_chars: border.BorderCharacters,

        border_widths: Padding,

        fit_content: bool,

        layout_properties: LayoutProperties,

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
                .fit_content = config.fit_content,
                .layout_properties = config.layout,
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

        pub fn render(self: *Self, area: Rect, frame: Frame) !void {
            const inner_area = Rect{
                .min = .{
                    .x = area.min.x + self.border_widths.left,
                    .y = area.min.y + self.border_widths.top,
                },
                .max = .{
                    .x = area.max.x -| self.border_widths.right,
                    .y = area.max.y -| self.border_widths.bottom,
                },
            };

            if (inner_area.min.x > inner_area.max.x or inner_area.min.y > inner_area.max.y) {
                try self.inner.render(area, frame);
            } else {
                try self.inner.render(inner_area, frame.with_area(inner_area));
                self.render_border(area, frame);
            }
        }

        pub fn layout(self: *Self, constraints: Constraints) !Vec2 {
            const props = self.layout_properties;
            const self_constraints = Constraints{
                .min_width = @max(props.min_width, constraints.min_width),
                .min_height = @max(props.min_height, constraints.min_height),
                .max_width = @min(props.max_width, constraints.max_width),
                .max_height = @min(props.max_height, constraints.max_height),
            };
            const border_size = Vec2{
                .x = self.border_widths.left + self.border_widths.right,
                .y = self.border_widths.top + self.border_widths.bottom,
            };
            const inner_constraints = Constraints{
                .min_width = self_constraints.min_width -| border_size.x,
                .min_height = self_constraints.min_height -| border_size.y,
                .max_width = self_constraints.max_width -| border_size.x,
                .max_height = self_constraints.max_height -| border_size.y,
            };
            const inner_size = try self.inner.layout(inner_constraints);

            var size = .{
                .x = self_constraints.max_width,
                .y = self_constraints.max_height,
            };
            if (self.fit_content or size.x == std.math.maxInt(u32)) {
                size.x = @min(size.x, inner_size.x + border_size.x);
            }
            if (self.fit_content or size.y == std.math.maxInt(u32)) {
                size.y = @min(size.y, inner_size.y + border_size.y);
            }

            return size;
        }

        pub fn handle_event(self: *Self, event: events.Event) !events.EventResult {
            return self.inner.handle_event(event);
        }

        pub fn layout_props(self: *Self) LayoutProperties {
            return self.layout_properties;
        }

        fn render_border(self: *Self, area: Rect, frame: Frame) void {
            var x = area.min.x;
            while (x < area.max.x) : (x += 1) {
                if (self.border.top)
                    frame.set_symbol(.{ .x = x, .y = area.min.y }, self.border_chars.top);
                if (self.border.bottom)
                    frame.set_symbol(.{ .x = x, .y = area.max.y - 1 }, self.border_chars.bottom);
            }

            var y = area.min.y;
            while (y < area.max.y) : (y += 1) {
                if (self.border.left)
                    frame.set_symbol(.{ .x = area.min.x, .y = y }, self.border_chars.left);
                if (self.border.right)
                    frame.set_symbol(.{ .x = area.max.x - 1, .y = y }, self.border_chars.right);
            }

            if (self.border.top and self.border.left)
                frame.set_symbol(.{ .x = area.min.x, .y = area.min.y }, self.border_chars.top_left);

            if (self.border.top and self.border.right)
                frame.set_symbol(.{ .x = area.max.x - 1, .y = area.min.y }, self.border_chars.top_right);

            if (self.border.bottom and self.border.left)
                frame.set_symbol(.{ .x = area.min.x, .y = area.max.y - 1 }, self.border_chars.bottom_left);

            if (self.border.bottom and self.border.right)
                frame.set_symbol(.{ .x = area.max.x - 1, .y = area.max.y - 1 }, self.border_chars.bottom_right);
        }
    };
}
