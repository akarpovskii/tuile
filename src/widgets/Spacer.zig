const std = @import("std");
const maxInt = std.math.maxInt;
const internal = @import("../internal.zig");
const Widget = @import("Widget.zig");
const Vec2 = @import("../Vec2.zig");
const Rect = @import("../Rect.zig");
const events = @import("../events.zig");
const Frame = @import("../render/Frame.zig");
const LayoutProperties = @import("LayoutProperties.zig");
const Constraints = @import("Constraints.zig");
const Theme = @import("../Theme.zig");

pub const Config = struct {
    // Spacer must either be flexible, or both max height and width must be defined.
    // Setting flex and max height/width at the same time may result in unexpected layout.
    layout: LayoutProperties = .{ .flex = 1 },
};

const Spacer = @This();

layout_properties: LayoutProperties,

pub fn create(config: Config) !*Spacer {
    const layout_ = config.layout;
    if (layout_.flex == 0 and (layout_.max_height == maxInt(u32) or layout_.max_width == maxInt(u32))) {
        @panic("Spacer must either be flexible, or both max height and width must be defined");
    }

    const self = try internal.allocator.create(Spacer);
    self.* = Spacer{
        .layout_properties = config.layout,
    };
    return self;
}

pub fn destroy(self: *Spacer) void {
    internal.allocator.destroy(self);
}

pub fn widget(self: *Spacer) Widget {
    return Widget.init(self);
}

pub fn render(_: *Spacer, _: Rect, _: Frame, _: Theme) !void {}

pub fn layout(self: *Spacer, constraints: Constraints) !Vec2 {
    const props = self.layout_properties;
    var size = Vec2{
        .x = @min(props.max_width, constraints.max_width),
        .y = @min(props.max_height, constraints.max_height),
    };
    if (size.x == maxInt(u32)) {
        size.x = 0;
    }
    if (size.y == maxInt(u32)) {
        size.y = 0;
    }
    return size;
}

pub fn handleEvent(_: *Spacer, _: events.Event) !events.EventResult {
    return .ignored;
}

pub fn layoutProps(self: *Spacer) LayoutProperties {
    return self.layout_properties;
}
