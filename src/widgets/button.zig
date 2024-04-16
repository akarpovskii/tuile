const std = @import("std");
const Widget = @import("Widget.zig");
const Vec2 = @import("../Vec2.zig");
const events = @import("../events.zig");
const Painter = @import("../Painter.zig");
const StyledWidget = @import("styled_widget.zig").StyledWidget;
const Label = @import("label.zig").Label;
const Style = @import("../Style.zig");

const Config = struct {
    label: []const u8,
};

pub fn Button(comptime config: Config) type {
    return struct {
        const Self = @This();

        const ViewType = StyledWidget(
            .{ .style = .{ .border = .{
                .top = "",
                .bottom = "",
                .left = "[",
                .right = "]",
                .top_left = "",
                .top_right = "",
                .bottom_left = "",
                .bottom_right = "",
            } } },
            Label(.{ .text = config.label, .wrap = false }),
        );

        allocator: std.mem.Allocator,

        view: *ViewType,

        focused: bool = false,

        pub fn create(allocator: std.mem.Allocator) !*Self {
            const view = try ViewType.create(allocator);

            const self = try allocator.create(Self);
            self.* = Self{
                .allocator = allocator,
                .view = view,
            };
            return self;
        }

        pub fn destroy(self: *Self) void {
            self.view.destroy();
            self.allocator.destroy(self);
        }

        pub fn widget(self: *Self) Widget {
            return Widget.init(self);
        }

        pub fn draw(self: *Self, painter: *Painter) !void {
            if (self.focused) try painter.backend.enable_effect(.Highlight);
            try self.view.draw(painter);
            if (self.focused) try painter.backend.disable_effect(.Highlight);
        }

        pub fn desired_size(self: *Self, available: Vec2) !Vec2 {
            return self.view.desired_size(available);
        }

        pub fn layout(self: *Self, bounds: Vec2) !void {
            return self.view.layout(bounds);
        }

        pub fn handle_event(self: *Self, event: events.Event) !events.EventResult {
            switch (event) {
                .FocusIn => return .Consumed,
                .FocusOut => {
                    self.focused = false;
                    // std.debug.print("\r\nbutton - {any}", .{event});
                    return .Consumed;
                },

                .Key, .ShiftKey => {
                    if (!self.focused) {
                        self.focused = true;
                        // std.debug.print("\r\nbutton - {any} consumed", .{event});
                        return .Consumed;
                    } else {
                        // std.debug.print("\r\nbutton - {any} ignored", .{event});
                        return .Ignored;
                    }
                },

                .Char => |char| switch (char) {
                    ' ' => {
                        // Handle button press
                        return .Consumed;
                    },
                    else => {},
                },
                else => {},
            }
            return .Ignored;
        }
    };
}
