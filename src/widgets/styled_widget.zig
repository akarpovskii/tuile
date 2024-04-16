const std = @import("std");
const Widget = @import("Widget.zig");
const Vec2 = @import("../Vec2.zig");
const events = @import("../events.zig");
const Painter = @import("../Painter.zig");
const Style = @import("../Style.zig");

pub fn StyledWidget(comptime Inner: anytype) type {
    return struct {
        const Self = @This();

        pub const Config = struct {
            style: Style = .{},
        };

        allocator: std.mem.Allocator,

        inner: *Inner,

        style: Style,

        size: ?Vec2 = null,

        border_widths: struct { top: u32, bottom: u32, left: u32, right: u32 },

        pub fn create(allocator: std.mem.Allocator, config: Config, inner: *Inner) !*Self {
            const border = config.style.border;

            const self = try allocator.create(Self);
            self.* = Self{
                .allocator = allocator,
                .inner = inner,
                .style = config.style,
                .border_widths = .{
                    .top = if (border.top.len == 0 and border.top_left.len == 0 and border.top_right.len == 0) 0 else 1,
                    .bottom = if (border.bottom.len == 0 and border.bottom_left.len == 0 and border.bottom_right.len == 0) 0 else 1,
                    .left = @intCast(try std.unicode.utf8CountCodepoints(border.left)),
                    .right = @intCast(try std.unicode.utf8CountCodepoints(border.right)),
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

            try painter.print_border(self.style.border, min, max);

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
    };
}
