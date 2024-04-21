const std = @import("std");
const Widget = @import("Widget.zig");
const Vec2 = @import("../Vec2.zig");
const Rect = @import("../Rect.zig");
const events = @import("../events.zig");
const Frame = @import("../render/Frame.zig");
const border = @import("border.zig");
const Padding = @import("Padding.zig");
const LayoutProperties = @import("LayoutProperties.zig");
const Constraints = @import("Constraints.zig");
const Theme = @import("../Theme.zig");

const Block = @This();

pub const Config = struct {
    border: border.Border = border.Border.none(),

    border_type: border.BorderType = .solid,

    padding: Padding = .{},

    fit_content: bool = false,

    layout: LayoutProperties = .{},
};

allocator: std.mem.Allocator,

inner: Widget,

inner_size: Vec2 = Vec2.zero(),

border: border.Border,

border_chars: border.BorderCharacters,

border_widths: Padding,

fit_content: bool,

layout_properties: LayoutProperties,

pub fn create(allocator: std.mem.Allocator, config: Config, inner: anytype) !*Block {
    const border_chars = border.BorderCharacters.fromType(config.border_type);

    const self = try allocator.create(Block);
    self.* = Block{
        .allocator = allocator,
        .inner = if (@TypeOf(inner) == Widget) inner else inner.widget(),
        .border = config.border,
        .border_chars = border_chars,
        .border_widths = .{
            .top = @intFromBool(config.border.top) + config.padding.top,
            .bottom = @intFromBool(config.border.bottom) + config.padding.bottom,
            .left = @intFromBool(config.border.left) + config.padding.left,
            .right = @intFromBool(config.border.right) + config.padding.right,
        },
        .fit_content = config.fit_content,
        .layout_properties = config.layout,
    };
    return self;
}

pub fn destroy(self: *Block) void {
    self.inner.destroy();
    self.allocator.destroy(self);
}

pub fn widget(self: *Block) Widget {
    return Widget.init(self);
}

pub fn render(self: *Block, area: Rect, frame: Frame, theme: Theme) !void {
    var content_area = Rect{
        .min = .{
            .x = area.min.x + self.border_widths.left,
            .y = area.min.y + self.border_widths.top,
        },
        .max = .{
            .x = area.max.x -| self.border_widths.right,
            .y = area.max.y -| self.border_widths.bottom,
        },
    };

    if (content_area.min.x > content_area.max.x or content_area.min.y > content_area.max.y) {
        self.renderBorder(area, frame, theme);
    } else {
        var inner_area = Rect{
            .min = content_area.min,
            .max = content_area.min.add(self.inner_size),
        };

        const props = self.inner.layoutProps();
        inner_area = content_area.alignInside(props.alignment, inner_area);

        try self.inner.render(inner_area, frame.withArea(inner_area), theme);
        self.renderBorder(area, frame, theme);
    }
}

pub fn layout(self: *Block, constraints: Constraints) !Vec2 {
    const props = self.layout_properties;
    const self_constraints = Constraints{
        .min_width = @max(props.min_width, constraints.min_width),
        .min_height = @max(props.min_height, constraints.min_height),
        .max_width = @min(props.max_width, constraints.max_width),
        .max_height = @min(props.max_height, constraints.max_height),
    };
    const border_size = Vec2{
        .x = self.border_widths.left + self.border_widths.right,
        .y = self.border_widths.top + self.border_widths.bottom,
    };
    const inner_constraints = Constraints{
        .min_width = 0,
        .min_height = 0,
        .max_width = self_constraints.max_width -| border_size.x,
        .max_height = self_constraints.max_height -| border_size.y,
    };
    self.inner_size = try self.inner.layout(inner_constraints);

    var size = .{
        .x = self_constraints.max_width,
        .y = self_constraints.max_height,
    };
    if (self.fit_content or size.x == std.math.maxInt(u32)) {
        size.x = @min(size.x, self.inner_size.x + border_size.x);
    }
    if (self.fit_content or size.y == std.math.maxInt(u32)) {
        size.y = @min(size.y, self.inner_size.y + border_size.y);
    }

    return size;
}

pub fn handleEvent(self: *Block, event: events.Event) !events.EventResult {
    return self.inner.handleEvent(event);
}

pub fn layoutProps(self: *Block) LayoutProperties {
    return self.layout_properties;
}

fn renderBorder(self: *Block, area: Rect, frame: Frame, _: Theme) void {
    const min = area.min;
    const max = area.max;
    const chars = self.border_chars;

    if (area.height() > 0) {
        // frame.set_style(.{ .min = min, .max = .{ .x = max.x, .y = min.y + 1 } }, .{ .fg = theme.primary });
        // frame.set_style(.{ .min = .{ .x = min.x, .y = max.y - 1 }, .max = max }, .{ .fg = theme.primary });

        var x = min.x;
        while (x < area.max.x) : (x += 1) {
            if (self.border.top)
                frame.setSymbol(.{ .x = x, .y = min.y }, chars.top);
            if (self.border.bottom)
                frame.setSymbol(.{ .x = x, .y = max.y - 1 }, chars.bottom);
        }
    }

    if (area.width() > 0) {
        // frame.set_style(.{ .min = min, .max = .{ .x = min.x + 1, .y = max.y } }, .{ .fg = theme.primary });
        // frame.set_style(.{ .min = .{ .x = max.x - 1, .y = min.y }, .max = max }, .{ .fg = theme.primary });

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
