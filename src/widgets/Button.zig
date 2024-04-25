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
    // text and span are mutually exclusive, only one of them must be defined
    text: ?[]const u8 = null,

    // text and span are mutually exclusive, only one of them must be defined
    span: ?display.SpanView = null,

    on_press: ?callbacks.Callback(void) = null,

    layout: LayoutProperties = .{},
};

pub const Button = @This();

view: *Label,

focus_handler: FocusHandler = .{},

on_press: ?callbacks.Callback(void),

pub fn create(config: Config) !*Button {
    if (config.text == null and config.span == null) {
        @panic("text and span are mutually exclusive, only one of them must be defined");
    }

    var label = display.Span.init(internal.allocator);
    defer label.deinit();

    try label.appendPlain("[");
    if (config.text) |text| {
        try label.appendPlain(text);
    } else if (config.span) |span| {
        try label.appendSpan(span);
    }
    try label.appendPlain("]");

    const view = try Label.create(
        .{ .span = label.view(), .layout = config.layout },
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
    frame.setStyle(area, .{ .bg = theme.interactive });
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
