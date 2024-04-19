const std = @import("std");
const Widget = @import("Widget.zig");
const Vec2 = @import("../Vec2.zig");
const Rect = @import("../Rect.zig");
const events = @import("../events.zig");
const Frame = @import("../render/Frame.zig");
const LayoutProperties = @import("LayoutProperties.zig");
const Constraints = @import("Constraints.zig");

pub const Orientation = enum {
    vertical,
    horizontal,
};

pub const Config = struct {
    orientation: Orientation = .vertical,

    layout: LayoutProperties = .{},
};

pub const StackLayout = @This();

allocator: std.mem.Allocator,

widgets: std.ArrayList(Widget),

widget_sizes: std.ArrayList(Vec2),

orientation: Orientation,

focused: ?usize = null,

layout_properties: LayoutProperties,

pub fn create(allocator: std.mem.Allocator, config: Config, children: anytype) !*StackLayout {
    var widgets = std.ArrayList(Widget).init(allocator);
    inline for (children) |child| {
        const w = if (@TypeOf(child) == Widget) child else child.widget();
        try widgets.append(w);
    }

    const self = try allocator.create(StackLayout);
    self.* = StackLayout{
        .allocator = allocator,
        .widgets = widgets,
        .widget_sizes = std.ArrayList(Vec2).init(allocator),
        .orientation = config.orientation,
        .layout_properties = config.layout,
    };
    return self;
}

pub fn add(self: *StackLayout, child: Widget) !void {
    try self.widgets.append(child);
}

pub fn destroy(self: *StackLayout) void {
    for (self.widgets.items) |w| {
        w.destroy();
    }
    self.widgets.deinit();
    self.widget_sizes.deinit();
    self.allocator.destroy(self);
}

pub fn widget(self: *StackLayout) Widget {
    return Widget.init(self);
}

pub fn render(self: *StackLayout, area: Rect, frame: Frame) !void {
    var cursor = area.min;

    for (self.widgets.items, self.widget_sizes.items) |w, s| {
        const widget_area = Rect{
            .min = cursor,
            .max = cursor.add(s),
        };
        try w.render(widget_area, frame.with_area(widget_area));
        switch (self.orientation) {
            .horizontal => {
                cursor.x += s.x;
            },
            .vertical => {
                cursor.y += s.y;
            },
        }
    }
}

pub fn layout(self: *StackLayout, constraints: Constraints) !Vec2 {
    switch (self.orientation) {
        .vertical => return try self.layout_impl(constraints, .vertical),
        .horizontal => return try self.layout_impl(constraints, .horizontal),
    }
}

pub fn layout_impl(self: *StackLayout, constraints: Constraints, comptime orientation: Orientation) !Vec2 {
    if (self.widgets.items.len == 0) {
        return .{ .x = constraints.min_width, .y = constraints.min_height };
    }

    comptime var min_main: []const u8 = undefined;
    comptime var min_cross: []const u8 = undefined;
    comptime var max_main: []const u8 = undefined;
    comptime var max_cross: []const u8 = undefined;
    comptime var main: []const u8 = undefined;
    comptime var cross: []const u8 = undefined;
    comptime {
        switch (orientation) {
            .vertical => {
                min_main = "min_height";
                min_cross = "min_width";
                max_main = "max_height";
                max_cross = "max_width";
                main = "y";
                cross = "x";
            },
            .horizontal => {
                min_main = "min_width";
                min_cross = "min_height";
                max_main = "max_width";
                max_cross = "max_height";
                main = "x";
                cross = "y";
            },
        }
    }

    self.widget_sizes.clearRetainingCapacity();
    try self.widget_sizes.resize(self.widgets.items.len);

    var flex_indices = std.ArrayList(usize).init(self.allocator);
    defer flex_indices.deinit();
    var fixed_indices = std.ArrayList(usize).init(self.allocator);
    defer fixed_indices.deinit();

    for (self.widgets.items, 0..) |w, idx| {
        const props = w.layout_props();
        const fixed = props.flex == 0;
        if (fixed or @field(constraints, max_main) == std.math.maxInt(u32)) {
            try fixed_indices.append(idx);
        } else {
            try flex_indices.append(idx);
        }
    }

    var self_size = Vec2.zero();
    var fixed_size: u32 = 0;
    for (fixed_indices.items) |idx| {
        const w = &self.widgets.items[idx];
        var w_cons = Constraints{};
        @field(w_cons, max_main) = std.math.maxInt(u32);
        @field(w_cons, max_cross) = @field(constraints, max_cross);
        const size = try w.layout(w_cons);

        self.widget_sizes.items[idx] = size;
        fixed_size += @field(size, main);
        @field(self_size, main) += @field(size, main);
        @field(self_size, cross) = @max(@field(self_size, cross), @field(size, cross));
    }

    var total_flex: u32 = 0;
    for (flex_indices.items) |idx| {
        const w = self.widgets.items[idx];
        const props = w.layout_props();
        total_flex += props.flex;
    }
    var remaining = @field(constraints, max_main) -| fixed_size;
    for (flex_indices.items) |idx| {
        const w = self.widgets.items[idx];
        const props = w.layout_props();
        const flex = props.flex;
        const weight = @as(f64, @floatFromInt(flex)) / @as(f64, @floatFromInt(total_flex));
        const main_size_f = @as(f64, @floatFromInt(remaining)) * weight;
        const widget_main_size = @as(u32, @intFromFloat(@round(main_size_f)));

        var w_cons = Constraints{};
        @field(w_cons, min_main) = widget_main_size;
        @field(w_cons, max_main) = widget_main_size;
        @field(w_cons, max_cross) = @field(constraints, max_cross);
        const size = try w.layout(w_cons);

        self.widget_sizes.items[idx] = size;
        @field(self_size, main) += @field(size, main);
        @field(self_size, cross) = @max(@field(self_size, cross), @field(size, cross));

        remaining -= widget_main_size;
        total_flex -= flex;
    }
    if (flex_indices.items.len > 0) std.debug.assert(remaining == 0);

    @field(self_size, cross) = @max(@field(self_size, cross), @field(constraints, min_cross));

    return self_size;
}

pub fn handle_event(self: *StackLayout, event: events.Event) !events.EventResult {
    if (event == .FocusIn) {
        var iter = WidgetsIterator.in_direction(self.widgets.items, event.FocusIn);
        return self.focus_on_next(&iter, event.FocusIn);
    }
    if (event == .FocusOut) {
        self.focused = null;
        return .Consumed;
    }

    if (self.focused == null) {
        // If nothing is focused, pressing Tab or Shift+Tab
        // technically generates two events: FocusIn and Key/ShiftKey.
        // If this is the case, we only need to pass down FocusIn to avoid changing the focus twice.
        var supress_further: bool = undefined;
        var direction: events.FocusDirection = undefined;

        switch (event) {
            .Key, .ShiftKey => |key| if (key == .Tab) {
                supress_further = true;
                direction = if (event == .Key) .front else .back;
            },
            else => {
                supress_further = false;
                direction = .front;
            },
        }

        if (try self.handle_event(.{ .FocusIn = direction }) == .Ignored) {
            return .Ignored;
        }
        if (supress_further) {
            return .Consumed;
        }
    }

    const active = self.focused.?;
    const active_w = self.widgets.items[active];

    switch (try active_w.handle_event(event)) {
        .Consumed => return .Consumed,
        .Ignored => {
            switch (event) {
                .Key, .ShiftKey => |key| if (key == .Tab) {
                    const direction: events.FocusDirection = if (event == .Key) .front else .back;

                    var iter = WidgetsIterator.in_direction(self.widgets.items, direction);
                    iter.current = @as(isize, @intCast(active)) + iter.step;

                    const focused = self.focus_on_next(&iter, direction);
                    _ = try active_w.handle_event(.FocusOut);
                    return focused;
                },
                else => {},
            }
        },
    }
    return .Ignored;
}

fn focus_on_next(self: *StackLayout, iter: *WidgetsIterator, direction: events.FocusDirection) !events.EventResult {
    while (iter.peek()) |w| : (_ = iter.next()) {
        if (try w.handle_event(.{ .FocusIn = direction }) == .Consumed) {
            self.focused = @intCast(iter.current);
            return .Consumed;
        }
    } else {
        self.focused = null;
        return .Ignored;
    }
}

const WidgetsIterator = struct {
    widgets: []Widget,

    step: isize,

    current: isize,

    pub fn in_direction(widgets: []Widget, direction: events.FocusDirection) WidgetsIterator {
        return switch (direction) {
            .front => forward(widgets),
            .back => backward(widgets),
        };
    }

    pub fn forward(widgets: []Widget) WidgetsIterator {
        return WidgetsIterator{
            .widgets = widgets,
            .step = 1,
            .current = 0,
        };
    }

    pub fn backward(widgets: []Widget) WidgetsIterator {
        return WidgetsIterator{
            .widgets = widgets,
            .step = -1,
            .current = @as(isize, @intCast(widgets.len)) - 1,
        };
    }

    pub fn next(self: *WidgetsIterator) ?*Widget {
        if (self.current < 0 or self.current >= self.widgets.len) {
            return null;
        }
        defer self.current += self.step;
        return &self.widgets[@intCast(self.current)];
    }

    pub fn peek(self: *WidgetsIterator) ?*Widget {
        if (self.current < 0 or self.current >= self.widgets.len) {
            return null;
        }
        return &self.widgets[@intCast(self.current)];
    }
};

pub fn layout_props(self: *StackLayout) LayoutProperties {
    return self.layout_properties;
}
