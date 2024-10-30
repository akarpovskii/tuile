const std = @import("std");
const internal = @import("../internal.zig");
const Widget = @import("Widget.zig");
const Vec2u = @import("../vec2.zig").Vec2u;
const Rect = @import("../rect.zig").Rect;
const events = @import("../events.zig");
const Frame = @import("../render/Frame.zig");
const border = @import("border.zig");
const Padding = @import("Padding.zig");
const LayoutProperties = @import("LayoutProperties.zig");
const Constraints = @import("Constraints.zig");
const display = @import("../display.zig");

pub const Config = struct {
    /// A unique identifier of the widget to be used in `Tuile.findById` and `Widget.findById`.
    id: ?[]const u8 = null,

    /// Which borders are visible, see `Border`.
    border: border.Border = border.Border.none(),

    /// The type of border, see `BorderType`.
    border_type: border.BorderType = .solid,

    /// Additional padding around the inner widget, see `Padding`.
    padding: Padding = .{},

    /// When `fit_content` is `false`, Block will try to take all the available space
    /// in the cross direction of a layout.
    fit_content: bool = false,

    /// Layout properties of the widget, see `LayoutProperties`.
    layout: LayoutProperties = .{},
};

const Block = @This();

pub usingnamespace Widget.SingleChild.Mixin(Block, .inner);
pub usingnamespace Widget.Base.Mixin(Block, .widget_base);

widget_base: Widget.Base,

inner: Widget,

inner_size: Vec2u = Vec2u.zero(),

border: border.Border,

border_type: border.BorderType,

padding: Padding,

fit_content: bool,

layout_properties: LayoutProperties,

pub fn create(config: Config, inner: anytype) !*Block {
    const self = try internal.allocator.create(Block);
    self.* = Block{
        .widget_base = try Widget.Base.init(config.id),
        .inner = try Widget.fromAny(inner),
        .border = config.border,
        .border_type = config.border_type,
        .padding = config.padding,
        .fit_content = config.fit_content,
        .layout_properties = config.layout,
    };
    return self;
}

pub fn destroy(self: *Block) void {
    self.widget_base.deinit();
    self.inner.destroy();
    internal.allocator.destroy(self);
}

pub fn widget(self: *Block) Widget {
    return Widget.init(self);
}

pub fn setInner(self: *Block, new_widget: Widget) void {
    self.inner.destroy();
    self.inner = new_widget;
}

pub fn render(self: *Block, area: Rect(i32), frame: Frame, theme: display.Theme) !void {
    var content_area = Rect(i32){
        .min = .{
            .x = area.min.x + @intFromBool(self.border.left) + @as(i32, @intCast(self.padding.left)),
            .y = area.min.y + @intFromBool(self.border.top) + @as(i32, @intCast(self.padding.top)),
        },
        .max = .{
            .x = area.max.x - (@intFromBool(self.border.right) + @as(i32, @intCast(self.padding.right))),
            .y = area.max.y - (@intFromBool(self.border.bottom) + @as(i32, @intCast(self.padding.bottom))),
        },
    };

    if (content_area.min.x > content_area.max.x or content_area.min.y > content_area.max.y) {
        self.renderBorder(area, frame, theme);
    } else {
        var inner_area = Rect(i32){
            .min = content_area.min,
            .max = .{
                // inner_size may contain std.math.maxInt(u32), but content_area is always finite.
                // Cast content_area to u32 first to get a finite value in @min, and then cast it back to i32
                .x = content_area.min.x + @as(i32, @intCast(@min(@as(u32, @intCast(content_area.width())), self.inner_size.x))),
                .y = content_area.min.y + @as(i32, @intCast(@min(@as(u32, @intCast(content_area.height())), self.inner_size.y))),
            },
        };

        const props = self.inner.layoutProps();
        inner_area = content_area.alignInside(props.alignment, inner_area);

        try self.inner.render(inner_area, frame.withArea(inner_area), theme);
        self.renderBorder(area, frame, theme);
    }
}

pub fn layout(self: *Block, constraints: Constraints) !Vec2u {
    const props = self.layout_properties;
    const self_constraints = Constraints{
        .min_width = @max(props.min_width, constraints.min_width),
        .min_height = @max(props.min_height, constraints.min_height),
        .max_width = @min(props.max_width, constraints.max_width),
        .max_height = @min(props.max_height, constraints.max_height),
    };
    const border_size = Vec2u{
        .x = @intFromBool(self.border.left) + self.padding.left + @intFromBool(self.border.right) + self.padding.right,
        .y = @intFromBool(self.border.top) + self.padding.top + @intFromBool(self.border.bottom) + self.padding.bottom,
    };
    const maxInt = std.math.maxInt;
    const inner_constraints = Constraints{
        .min_width = 0,
        .min_height = 0,

        .max_width = if (self_constraints.max_width == maxInt(u32))
            self_constraints.max_width
        else
            self_constraints.max_width -| border_size.x,

        .max_height = if (self_constraints.max_height == maxInt(u32))
            self_constraints.max_height
        else
            self_constraints.max_height -| border_size.y,
    };
    self.inner_size = try self.inner.layout(inner_constraints);

    var size = .{
        .x = self_constraints.max_width,
        .y = self_constraints.max_height,
    };
    if (self.fit_content or size.x == maxInt(u32)) {
        size.x = @min(size.x, self.inner_size.x +| border_size.x);
    }
    if (self.fit_content or size.y == maxInt(u32)) {
        size.y = @min(size.y, self.inner_size.y +| border_size.y);
    }

    return size;
}

pub fn handleEvent(self: *Block, event: events.Event) !events.EventResult {
    return self.inner.handleEvent(event);
}

pub fn layoutProps(self: *Block) LayoutProperties {
    return self.layout_properties;
}

fn renderBorder(self: *Block, area: Rect(i32), frame: Frame, theme: display.Theme) void {
    const min = area.min;
    const max = area.max;
    const chars = border.BorderCharacters.fromType(self.border_type);

    if (area.height() > 0) {
        if (self.border.top)
            frame.setStyle(.{ .min = min, .max = .{ .x = max.x, .y = min.y + 1 } }, .{ .fg = theme.borders });
        if (self.border.bottom)
            frame.setStyle(.{ .min = .{ .x = min.x, .y = max.y - 1 }, .max = max }, .{ .fg = theme.borders });

        var x = min.x;
        while (x < area.max.x) : (x += 1) {
            if (self.border.top)
                frame.setSymbol(.{ .x = x, .y = min.y }, chars.top);
            if (self.border.bottom)
                frame.setSymbol(.{ .x = x, .y = max.y - 1 }, chars.bottom);
        }
    }

    if (area.width() > 0) {
        if (self.border.left)
            frame.setStyle(.{ .min = min, .max = .{ .x = min.x + 1, .y = max.y } }, .{ .fg = theme.borders });
        if (self.border.right)
            frame.setStyle(.{ .min = .{ .x = max.x - 1, .y = min.y }, .max = max }, .{ .fg = theme.borders });

        var y = min.y;
        while (y < max.y) : (y += 1) {
            if (self.border.left)
                frame.setSymbol(.{ .x = min.x, .y = y }, chars.left);
            if (self.border.right)
                frame.setSymbol(.{ .x = max.x - 1, .y = y }, chars.right);
        }
    }

    if (area.height() > 1 and area.width() > 1) {
        if (self.border.top and self.border.left)
            frame.setSymbol(.{ .x = min.x, .y = min.y }, chars.top_left);

        if (self.border.top and self.border.right)
            frame.setSymbol(.{ .x = max.x - 1, .y = min.y }, chars.top_right);

        if (self.border.bottom and self.border.left)
            frame.setSymbol(.{ .x = min.x, .y = max.y - 1 }, chars.bottom_left);

        if (self.border.bottom and self.border.right)
            frame.setSymbol(.{ .x = max.x - 1, .y = max.y - 1 }, chars.bottom_right);
    }
}

pub fn prepare(self: *Block) !void {
    try self.inner.prepare();
}
