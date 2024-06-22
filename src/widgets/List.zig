const std = @import("std");
const Widget = @import("Widget.zig");
const Label = @import("Label.zig");
const LayoutProperties = @import("LayoutProperties.zig");
const Rect = @import("../rect.zig").Rect;
const Vec2u = @import("../vec2.zig").Vec2u;
const Constraints = @import("Constraints.zig");
const Frame = @import("../render/Frame.zig");
const FocusHandler = @import("FocusHandler.zig");
const callbacks = @import("callbacks.zig");
const display = @import("../display.zig");
const events = @import("../events.zig");
const internal = @import("../internal.zig");

pub const Config = struct {
    /// A unique identifier of the widget to be used in `Tuile.findById` and `Widget.findById`.
    id: ?[]const u8 = null,

    /// Layout properties of the widget, see `LayoutProperties`.
    layout: LayoutProperties = .{},

    /// List will call this when pressed passing the selected value.
    on_press: ?callbacks.Callback(?*anyopaque) = null,
};

const List = @This();

pub usingnamespace Widget.Leaf.Mixin(List);
pub usingnamespace Widget.Base.Mixin(List, .widget_base);

widget_base: Widget.Base,

layout_properties: LayoutProperties,

items: std.ArrayListUnmanaged(Item),

top_index: usize = 0,

top_overflow: usize = 0,

selected_index: usize = 0,

focus_handler: FocusHandler = .{},

on_press: ?callbacks.Callback(?*anyopaque),

item_sizes: std.ArrayListUnmanaged(Vec2u),

pub const Item = struct {
    label: *Label,

    value: ?*anyopaque,
};

pub fn create(config: Config, items: []const Item) !*List {
    const self = try internal.allocator.create(List);
    self.* = .{
        .widget_base = try Widget.Base.init(config.id),
        .layout_properties = config.layout,
        .items = std.ArrayListUnmanaged(Item){},
        .item_sizes = std.ArrayListUnmanaged(Vec2u){},
        .on_press = config.on_press,
    };
    try self.items.appendSlice(internal.allocator, items);
    return self;
}

pub fn destroy(self: *List) void {
    for (self.items.items) |item| {
        item.label.destroy();
    }
    self.items.deinit(internal.allocator);
    self.widget_base.deinit();
    internal.allocator.destroy(self);
}

pub fn widget(self: *List) Widget {
    return Widget.init(self);
}

pub fn render(self: *List, area: Rect(i32), frame: Frame, theme: display.Theme) !void {
    var cursor = area.min;
    cursor.y -= @intCast(self.top_overflow);

    for (self.top_index..self.top_index + self.item_sizes.items.len) |index| {
        const item = self.items.items[index];
        const size = self.item_sizes.items[index - self.top_index];
        const props = item.label.layoutProps();
        const alignment = props.alignment;

        var item_area = Rect(i32){
            .min = cursor,
            .max = cursor.add(size.as(i32)),
        };
        item_area = area.alignH(alignment.h, item_area);
        const item_frame = frame.withArea(item_area);

        if (index == self.selected_index) {
            self.focus_handler.render(item_area, item_frame, theme);
        }
        try item.label.render(item_area, item_frame, theme);
        cursor.y += @intCast(size.y);
    }
}

pub fn layout(self: *List, constraints: Constraints) !Vec2u {
    const self_constraints = Constraints.fromProps(self.layout_properties);
    const item_constraints = Constraints{
        .min_height = 0,
        .min_width = 0,
        .max_height = std.math.maxInt(u32),
        .max_width = @min(self_constraints.max_width, constraints.max_width),
    };

    if (self.selected_index < self.top_index) {
        self.top_index = self.selected_index;
    }

    var total_size = Vec2u.zero();
    const max_height = @min(self_constraints.max_height, constraints.max_height);
    self.item_sizes.clearRetainingCapacity();
    var index = self.top_index;
    // When selection is below the current window, we need all the sizes until the selection
    // in order to backtrack below and layout everything from bottom to top.
    while ((total_size.y < max_height and index < self.items.items.len) or index <= self.selected_index) {
        const item = self.items.items[index];
        const size = try item.label.layout(item_constraints);

        total_size.x = @max(total_size.x, size.x);
        total_size.y += size.y;

        try self.item_sizes.append(internal.allocator, size);
        index += 1;
    }

    // Selection moved down and outside the current window.
    // Update top_index and top_overflow.
    self.top_overflow = 0;
    if (index == self.selected_index + 1 and self.selected_index != self.top_index and total_size.y > max_height) {
        var fits: usize = 0;
        total_size = Vec2u.zero();
        var reverse_iter = std.mem.reverseIterator(self.item_sizes.items);
        while (reverse_iter.next()) |size| {
            total_size.x = @max(total_size.x, size.x);
            total_size.y += size.y;
            fits += 1;
            if (total_size.y >= max_height) {
                break;
            }
        }
        self.top_overflow = total_size.y - max_height;
        const offset = self.item_sizes.items.len - fits;
        self.top_index += offset;
        self.item_sizes.replaceRangeAssumeCapacity(0, self.item_sizes.items.len - fits, &.{});
    }

    total_size = self_constraints.apply(total_size);
    total_size = constraints.apply(total_size);
    return total_size;
}

pub fn handleEvent(self: *List, event: events.Event) !events.EventResult {
    if (self.focus_handler.handleEvent(event) == .consumed) {
        return .consumed;
    }

    switch (event) {
        .key => |key| switch (key) {
            .Up => {
                if (self.selected_index > 0) {
                    self.selected_index -= 1;
                }
                return .consumed;
            },
            .Down => {
                if (self.selected_index + 1 < self.items.items.len) {
                    self.selected_index += 1;
                }
                return .consumed;
            },
            else => {},
        },
        .char => |char| switch (char) {
            ' ' => {
                if (self.on_press) |on_press| {
                    on_press.call(self.items.items[self.selected_index].value);
                }
                return .consumed;
            },
            else => {},
        },
        else => {},
    }
    return .ignored;
}

pub fn layoutProps(self: *List) LayoutProperties {
    return self.layout_properties;
}

pub fn scrollUp(self: *List) void {
    self.selected_index = 0;
}

pub fn scrollDown(self: *List) void {
    self.selected_index = self.items.items.len;
}
