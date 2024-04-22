const std = @import("std");
const internal = @import("../internal.zig");
const Widget = @import("Widget.zig");
const Vec2 = @import("../Vec2.zig");
const Rect = @import("../Rect.zig");
const events = @import("../events.zig");
const Frame = @import("../render/Frame.zig");
const Label = @import("Label.zig");
const FocusHandler = @import("FocusHandler.zig");
const LayoutProperties = @import("LayoutProperties.zig");
const Constraints = @import("Constraints.zig");
const display = @import("../display/display.zig");
const callbacks = @import("callbacks.zig");

pub const Config = struct {
    label: []const u8,

    on_press: ?callbacks.Callback(void) = null,

    layout: LayoutProperties = .{},
};

pub const Button = @This();

view: *Label,

focus_handler: FocusHandler = .{},

on_press: ?callbacks.Callback(void),

pub fn create(config: Config) !*Button {
    var label = try internal.allocator.alloc(u8, config.label.len + 2);
    defer internal.allocator.free(label);

    std.mem.copyForwards(u8, label[1..], config.label);
    label[0] = '[';
    label[label.len - 1] = ']';

    const view = try Label.create(
        .{ .text = label, .layout = config.layout },
    );

    const self = try internal.allocator.create(Button);
    self.* = Button{
        .view = view,
        .on_press = config.on_press,
    };
    return self;
}

pub fn destroy(self: *Button) void {
    self.view.destroy();
    internal.allocator.destroy(self);
}

pub fn widget(self: *Button) Widget {
    return Widget.init(self);
}

pub fn render(self: *Button, area: Rect, frame: Frame, theme: display.Theme) !void {
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
