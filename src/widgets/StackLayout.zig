const std = @import("std");
const Widget = @import("Widget.zig");
const Vec2 = @import("../Vec2.zig");
const Rect = @import("../Rect.zig");
const events = @import("../events.zig");
const Frame = @import("../render/Frame.zig");

const Orientation = enum {
    Horizontal,
    Vertical,
};

pub const Config = struct {
    orientation: Orientation = .Vertical,
};

pub const StackLayout = @This();

allocator: std.mem.Allocator,

widgets: std.ArrayList(Widget),

widget_sizes: std.ArrayList(Vec2),

orientation: Orientation,

focused: ?usize = null,

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

pub fn render(self: *StackLayout, area: Rect, frame: *Frame) !void {
    var cursor = area.min;

    for (self.widgets.items, self.widget_sizes.items) |w, s| {
        const widget_area = Rect{
            .min = cursor,
            .max = cursor.add(s),
        };
        try w.render(widget_area, frame);
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

pub fn desired_size(self: *StackLayout, available: Vec2) !Vec2 {
    var size = Vec2.zero();
    for (self.widgets.items) |w| {
        const w_size = try w.desired_size(available);

        switch (self.orientation) {
            .Horizontal => {
                size.x += w_size.x;
                size.y = @max(size.y, w_size.y);
            },
            .Vertical => {
                size.x = @max(size.x, w_size.x);
                size.y += w_size.y;
            },
        }
    }
    return size;
}

pub fn layout(self: *StackLayout, bounds: Vec2) !void {
    if (self.widgets.items.len == 0) {
        return;
    }

    const len: u32 = @intCast(self.widgets.items.len);

    self.widget_sizes.clearRetainingCapacity();
    try self.widget_sizes.ensureTotalCapacity(len);
    for (self.widgets.items) |w| {
        const size = try w.desired_size(bounds);
        self.widget_sizes.append(size) catch unreachable;
    }

    switch (self.orientation) {
        .Horizontal => {
            // Limit in cross axis
            for (self.widget_sizes.items) |*s| {
                s.y = @min(s.y, bounds.y);
            }

            // Layout in main axis
            var total: u32 = 0;
            for (self.widget_sizes.items) |s| {
                total += s.x;
            }

            if (total > bounds.x) {
                var extra = total - bounds.x;
                var reverse = std.mem.reverseIterator(self.widget_sizes.items);
                while (reverse.nextPtr()) |s| {
                    if (extra == 0) break;
                    const sub = @min(extra, s.x);
                    extra -= sub;
                    s.x -= sub;
                }
                std.debug.assert(extra == 0);
            }
        },

        .Vertical => {
            // Limit in cross axis
            for (self.widget_sizes.items) |*s| {
                s.x = @min(s.x, bounds.x);
            }

            // Layout in main axis
            var total: u32 = 0;
            for (self.widget_sizes.items) |s| {
                total += s.y;
            }

            if (total > bounds.y) {
                var extra = total - bounds.y;
                var reverse = std.mem.reverseIterator(self.widget_sizes.items);
                while (reverse.nextPtr()) |s| {
                    if (extra == 0) break;
                    const sub = @min(extra, s.y);
                    extra -= sub;
                    s.y -= sub;
                }
                std.debug.assert(extra == 0);
            }
        },
    }

    for (self.widgets.items, self.widget_sizes.items) |w, s| {
        try w.layout(s);
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
