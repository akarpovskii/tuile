const std = @import("std");
const internal = @import("../internal.zig");
const Widget = @import("Widget.zig");
const Vec2 = @import("../Vec2.zig");
const Rect = @import("../Rect.zig");
const events = @import("../events.zig");
const Frame = @import("../render/Frame.zig");
const LayoutProperties = @import("LayoutProperties.zig");
const Constraints = @import("Constraints.zig");
const Theme = @import("../display/Theme.zig");

const maxInt = std.math.maxInt;

pub const Config = struct {
    /// A unique identifier of the widget to be used in `Tuile.findById` and `Widget.findById`.
    id: ?[]const u8 = null,

    /// Layout properties of the widget, see `LayoutProperties`.
    /// Spacer must either be flexible, or both max height and width must be defined.
    /// Setting flex and max height/width at the same time may result in unexpected layout.
    layout: LayoutProperties = .{ .flex = 1 },
};

const Spacer = @This();

pub usingnamespace Widget.Leaf.Mixin(Spacer);
pub usingnamespace Widget.Base.Mixin(Spacer, .widget_base);

widget_base: Widget.Base,

layout_properties: LayoutProperties,

pub fn create(config: Config) !*Spacer {
    const layout_ = config.layout;
    if (layout_.flex == 0 and (layout_.max_height == maxInt(u32) or layout_.max_width == maxInt(u32))) {
        @panic("Spacer must either be flexible, or both max height and width must be defined");
    }

    const self = try internal.allocator.create(Spacer);
    self.* = Spacer{
        .widget_base = try Widget.Base.init(config.id),
        .layout_properties = config.layout,
    };
    return self;
}

pub fn destroy(self: *Spacer) void {
    self.widget_base.deinit();
    internal.allocator.destroy(self);
}

pub fn widget(self: *Spacer) Widget {
    return Widget.init(self);
}

pub fn render(_: *Spacer, _: Rect, _: Frame, _: Theme) !void {}

pub fn layout(self: *Spacer, constraints: Constraints) !Vec2 {
    const props = self.layout_properties;
    const size = Vec2{
        .x = @min(props.max_width, constraints.max_width),
        .y = @min(props.max_height, constraints.max_height),
    };
    // if (size.x == maxInt(u32)) {
    //     size.x = 0;
    // }
    // if (size.y == maxInt(u32)) {
    //     size.y = 0;
    // }
    return size;
}

pub fn handleEvent(_: *Spacer, _: events.Event) !events.EventResult {
    return .ignored;
}

pub fn layoutProps(self: *Spacer) LayoutProperties {
    return self.layout_properties;
}
