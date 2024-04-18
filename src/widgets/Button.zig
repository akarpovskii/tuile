const std = @import("std");
const Widget = @import("Widget.zig");
const Vec2 = @import("../Vec2.zig");
const Rect = @import("../Rect.zig");
const events = @import("../events.zig");
const Frame = @import("../render/Frame.zig");
const Label = @import("Label.zig");
const Style = @import("../Style.zig");

pub const Config = struct {
    label: []const u8,

    on_press: ?*const fn (label: []const u8) void = null,
};

pub const Button = @This();

allocator: std.mem.Allocator,

view: *Label,

focused: bool = false,

on_press: ?*const fn (label: []const u8) void,

pub fn create(allocator: std.mem.Allocator, config: Config) !*Button {
    var label = try allocator.alloc(u8, config.label.len + 2);
    defer allocator.free(label);

    std.mem.copyForwards(u8, label[1..], config.label);
    label[0] = '[';
    label[label.len - 1] = ']';

    const view = try Label.create(
        allocator,
        .{ .text = label, .wrap = false },
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

pub fn render(self: *Button, area: Rect, frame: *Frame) !void {
    if (self.focused) frame.set_style(area, .{ .add_effect = .{ .highlight = true } });
    try self.view.render(area, frame);
}

pub fn desired_size(self: *Button, available: Vec2) !Vec2 {
    return self.view.desired_size(available);
}

pub fn layout(self: *Button, bounds: Vec2) !void {
    return self.view.layout(bounds);
}

pub fn handle_event(self: *Button, event: events.Event) !events.EventResult {
    switch (event) {
        .FocusIn => {
            self.focused = true;
            return .Consumed;
        },
        .FocusOut => {
            self.focused = false;
            return .Consumed;
        },

        .Char => |char| switch (char) {
            ' ' => {
                if (self.on_press) |on_press| {
                    on_press(self.view.text);
                }
                return .Consumed;
            },
            else => {},
        },
        else => {},
    }
    return .Ignored;
}
