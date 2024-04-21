const std = @import("std");
const Widget = @import("Widget.zig");
const Vec2 = @import("../Vec2.zig");
const Rect = @import("../Rect.zig");
const events = @import("../events.zig");
const Frame = @import("../render/Frame.zig");
const Label = @import("Label.zig");
const Style = @import("../Style.zig");
const FocusHandler = @import("FocusHandler.zig");
const LayoutProperties = @import("LayoutProperties.zig");
const Constraints = @import("Constraints.zig");
const Theme = @import("../Theme.zig");
const callbacks = @import("callbacks.zig");

pub const Config = struct {
    label: []const u8,

    on_press: ?callbacks.Callback(void) = null,

    layout: LayoutProperties = .{},
};

pub const Button = @This();

allocator: std.mem.Allocator,

view: *Label,

focus_handler: FocusHandler = .{},

on_press: ?callbacks.Callback(void),

pub fn create(allocator: std.mem.Allocator, config: Config) !*Button {
    var label = try allocator.alloc(u8, config.label.len + 2);
    defer allocator.free(label);

    std.mem.copyForwards(u8, label[1..], config.label);
    label[0] = '[';
    label[label.len - 1] = ']';

    const view = try Label.create(
        allocator,
        .{ .text = label, .layout = config.layout },
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

pub fn render(self: *Button, area: Rect, frame: Frame, theme: Theme) !void {
    self.focus_handler.render(area, frame, theme);
    try self.view.render(area, frame, theme);
}

pub fn layout(self: *Button, constraints: Constraints) !Vec2 {
    return self.view.layout(constraints);
}

pub fn handleEvent(self: *Button, event: events.Event) !events.EventResult {
    if (self.focus_handler.handleEvent(event) == .consumed) {
        return .consumed;
    }

    switch (event) {
        .char => |char| switch (char) {
            ' ' => {
                if (self.on_press) |on_press| {
                    on_press.call();
                }
                return .consumed;
            },
            else => {},
        },
        else => {},
    }
    return .ignored;
}

pub fn layoutProps(self: *Button) LayoutProperties {
    return self.view.layoutProps();
}
