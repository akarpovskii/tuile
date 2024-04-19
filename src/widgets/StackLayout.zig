const std = @import("std");
const Widget = @import("Widget.zig");
const Vec2 = @import("../Vec2.zig");
const Rect = @import("../Rect.zig");
const events = @import("../events.zig");
const Frame = @import("../render/Frame.zig");
const Sized = @import("Sized.zig");
const Constraints = @import("Constraints.zig");

const Orientation = enum {
    Horizontal,
    Vertical,
};

pub const Config = struct {
    orientation: Orientation = .Vertical,

    sized: Sized = .{},
};

pub const StackLayout = @This();

allocator: std.mem.Allocator,

widgets: std.ArrayList(Widget),

widget_sizes: std.ArrayList(Vec2),

orientation: Orientation,

focused: ?usize = null,

sized: Sized,

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
        .sized = config.sized,
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
            .Horizontal => {
                cursor.x += s.x;
            },
            .Vertical => {
                cursor.y += s.y;
            },
        }
    }
}

pub fn layout(self: *StackLayout, constraints: Constraints) !Vec2 {
    if (self.widgets.items.len == 0) {
        return .{ .x = constraints.min_width, .y = constraints.min_height };
    }

    switch (self.orientation) {
        .Vertical => {
            self.widget_sizes.clearRetainingCapacity();
            try self.widget_sizes.resize(self.widgets.items.len);

            var flex_indices = std.ArrayList(usize).init(self.allocator);
            defer flex_indices.deinit();
            var fixed_indices = std.ArrayList(usize).init(self.allocator);
            defer fixed_indices.deinit();

            for (self.widgets.items, 0..) |w, idx| {
                const fixed = w.flex() == 0;
                if (fixed or constraints.max_height == std.math.maxInt(u32)) {
                    try fixed_indices.append(idx);
                } else {
                    try flex_indices.append(idx);
                }
            }

            var self_size = Vec2.zero();
            var fixed_height: u32 = 0;
            for (fixed_indices.items) |idx| {
                const w = &self.widgets.items[idx];
                const size = try w.layout(.{
                    .max_height = std.math.maxInt(u32),
                    .max_width = constraints.max_width,
                });

                self.widget_sizes.items[idx] = size;
                fixed_height += size.y;
                self_size.y += size.y;
                self_size.x = @max(self_size.x, size.x);
            }

            var total_flex: u32 = 0;
            for (flex_indices.items) |idx| {
                const w = self.widgets.items[idx];
                total_flex += w.flex();
            }
            var remaining = constraints.max_height -| fixed_height;
            for (flex_indices.items) |idx| {
                const w = self.widgets.items[idx];
                const flex = w.flex();
                const weight = @as(f64, @floatFromInt(flex)) / @as(f64, @floatFromInt(total_flex));
                const height_f = @as(f64, @floatFromInt(remaining)) * weight;
                const widget_height = @as(u32, @intFromFloat(@round(height_f)));

                const size = try w.layout(.{
                    .min_height = widget_height,
                    .max_height = widget_height,
                    .max_width = constraints.max_width,
                });

                self.widget_sizes.items[idx] = size;
                self_size.y += size.y;
                self_size.x = @max(self_size.x, size.x);

                remaining -= widget_height;
                total_flex -= flex;
            }
            if (flex_indices.items.len > 0) std.debug.assert(remaining == 0);

            self_size.x = @max(self_size.x, constraints.min_width);

            return self_size;
        },
        .Horizontal => {
            self.widget_sizes.clearRetainingCapacity();
            try self.widget_sizes.resize(self.widgets.items.len);

            var flex_indices = std.ArrayList(usize).init(self.allocator);
            defer flex_indices.deinit();
            var fixed_indices = std.ArrayList(usize).init(self.allocator);
            defer fixed_indices.deinit();

            for (self.widgets.items, 0..) |w, idx| {
                const fixed = w.flex() == 0;
                if (fixed or constraints.max_width == std.math.maxInt(u32)) {
                    try fixed_indices.append(idx);
                } else {
                    try flex_indices.append(idx);
                }
            }

            var self_size = Vec2.zero();
            var fixed_width: u32 = 0;
            for (fixed_indices.items) |idx| {
                const w = &self.widgets.items[idx];
                const size = try w.layout(.{
                    .max_height = constraints.max_height,
                    .max_width = std.math.maxInt(u32),
                });

                self.widget_sizes.items[idx] = size;
                fixed_width += size.x;
                self_size.x += size.x;
                self_size.y = @max(self_size.y, size.y);
            }

            var total_flex: u32 = 0;
            for (flex_indices.items) |idx| {
                const w = self.widgets.items[idx];
                total_flex += w.flex();
            }
            var remaining = constraints.max_width -| fixed_width;
            for (flex_indices.items) |idx| {
                const w = self.widgets.items[idx];
                const flex = w.flex();
                const weight = @as(f64, @floatFromInt(flex)) / @as(f64, @floatFromInt(total_flex));
                const portion = @as(f64, @floatFromInt(remaining)) * weight;
                const widget_width = @as(u32, @intFromFloat(@round(portion)));

                const size = try w.layout(.{
                    .min_width = widget_width,
                    .max_width = widget_width,
                    .max_height = constraints.max_height,
                });

                self.widget_sizes.items[idx] = size;
                self_size.x += size.x;
                self_size.y = @max(self_size.y, size.y);

                remaining -= widget_width;
                total_flex -= flex;
            }
            if (flex_indices.items.len > 0) std.debug.assert(remaining == 0);

            self_size.y = @max(self_size.y, constraints.min_height);

            return self_size;
        },
    }
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
