const std = @import("std");
const Widget = @import("Widget.zig");
const Vec2 = @import("../Vec2.zig");
const events = @import("../events.zig");
const Painter = @import("../Painter.zig");
const StyledWidget = @import("styled_widget.zig").StyledWidget;
const Label = @import("label.zig").Label;
const Style = @import("../Style.zig");

pub const Config = struct {
    label: []const u8,

    on_press: ?*const fn (label: []const u8) void = null,
};

pub const Button = @This();

allocator: std.mem.Allocator,

view: *StyledWidget(Label),

focused: bool = false,

on_press: ?*const fn (label: []const u8) void,

pub fn create(allocator: std.mem.Allocator, config: Config) !*Button {
    const view = try StyledWidget(Label).create(
        allocator,
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
        try Label.create(
            allocator,
            .{ .text = config.label, .wrap = false },
        ),
    );

    const self = try allocator.create(Button);
    self.* = Button{
        .allocator = allocator,
        .view = view,
        .on_press = config.on_press,
    };
    return self;
}

pub fn destroy(self: *Button) void {
    self.view.destroy();
    self.allocator.destroy(self);
}

pub fn widget(self: *Button) Widget {
    return Widget.init(self);
}

pub fn draw(self: *Button, painter: *Painter) !void {
    if (self.focused) try painter.backend.enable_effect(.Highlight);
    try self.view.draw(painter);
    if (self.focused) try painter.backend.disable_effect(.Highlight);
}

pub fn desired_size(self: *Button, available: Vec2) !Vec2 {
    return self.view.desired_size(available);
}

pub fn layout(self: *Button, bounds: Vec2) !void {
    return self.view.layout(bounds);
}

pub fn handle_event(self: *Button, event: events.Event) !events.EventResult {
    switch (event) {
        .FocusIn => return .Consumed,
        .FocusOut => {
            self.focused = false;
            return .Consumed;
        },

        .Key, .ShiftKey => {
            if (!self.focused) {
                self.focused = true;
                return .Consumed;
            } else {
                return .Ignored;
            }
        },

        .Char => |char| switch (char) {
            ' ' => {
                if (self.on_press) |on_press| {
                    on_press(self.view.inner.text);
                }
                return .Consumed;
            },
            else => {},
        },
        else => {},
    }
    return .Ignored;
}
