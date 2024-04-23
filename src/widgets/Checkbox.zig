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

    checked: bool = false,

    on_state_change: ?callbacks.Callback(bool) = null,

    layout: LayoutProperties = .{},
};

pub const Checkbox = @This();

labels: [2]*Label,

focus_handler: FocusHandler = .{},

layout_properties: LayoutProperties,

checked: bool,

on_state_change: ?callbacks.Callback(bool),

fn createLabelWithMarker(marker: []const u8, config: Config) !*Label {
    var label = display.Span.init(internal.allocator);
    defer label.deinit();

    try label.appendPlain(marker);
    if (config.text) |text| {
        try label.appendPlain(text);
    } else if (config.span) |span| {
        try label.appendSpan(span);
    }

    return try Label.create(
        .{ .span = label.view(), .layout = config.layout },
    );
}

pub fn create(config: Config) !*Checkbox {
    if (config.text == null and config.span == null) {
        @panic("text and span are mutually exclusive, only one of them must be defined");
    }

    const labels: [2]*Label = .{
        try createLabelWithMarker("[ ] ", config),
        try createLabelWithMarker("[*] ", config),
    };

    const self = try internal.allocator.create(Checkbox);
    self.* = Checkbox{
        .labels = labels,
        .checked = config.checked,
        .layout_properties = config.layout,
        .on_state_change = config.on_state_change,
    };
    return self;
}

pub fn destroy(self: *Checkbox) void {
    for (self.labels) |label| {
        label.destroy();
    }
    internal.allocator.destroy(self);
}

pub fn widget(self: *Checkbox) Widget {
    return Widget.init(self);
}

pub fn render(self: *Checkbox, area: Rect, frame: Frame, theme: display.Theme) !void {
    self.focus_handler.render(area, frame, theme);
    if (self.checked) {
        try self.labels[1].render(area, frame, theme);
    } else {
        try self.labels[0].render(area, frame, theme);
    }
}

pub fn layout(self: *Checkbox, constraints: Constraints) !Vec2 {
    if (self.checked) {
        return try self.labels[1].layout(constraints);
    } else {
        return try self.labels[0].layout(constraints);
    }
}

pub fn handleEvent(self: *Checkbox, event: events.Event) !events.EventResult {
    if (self.focus_handler.handleEvent(event) == .consumed) {
        return .consumed;
    }
    switch (event) {
        .char => |char| switch (char) {
            ' ' => {
                self.checked = !self.checked;
                if (self.on_state_change) |on_state_change| {
                    on_state_change.call(self.checked);
                }
                return .consumed;
            },
            else => {},
        },
        else => {},
    }
    return .ignored;
}

pub fn layoutProps(self: *Checkbox) LayoutProperties {
    return self.layout_properties;
}
