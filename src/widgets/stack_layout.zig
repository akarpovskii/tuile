const std = @import("std");
const Widget = @import("Widget.zig");
const Vec2 = @import("../Vec2.zig");
const events = @import("../events.zig");
const Painter = @import("../Painter.zig");

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

pub fn draw(self: *StackLayout, painter: *Painter) !void {
    var cursor = painter.cursor;

    for (self.widgets.items, self.widget_sizes.items) |w, s| {
        painter.move_to(cursor);
        try w.draw(painter);
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
                const per_widget = std.math.divCeil(u32, extra, len) catch 0;
                for (self.widget_sizes.items) |*s| {
                    if (extra > per_widget) {
                        s.x -= @min(per_widget, s.x);
                        extra -= per_widget;
                    } else {
                        s.x -= @min(extra, s.x);
                        break;
                    }
                }
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
                const per_widget = std.math.divCeil(u32, extra, len) catch 0;
                for (self.widget_sizes.items) |*s| {
                    if (extra > per_widget) {
                        s.y -= @min(per_widget, s.x);
                        extra -= per_widget;
                    } else {
                        s.y -= @min(extra, s.x);
                        break;
                    }
                }
            }
        },
    }

    for (self.widgets.items, self.widget_sizes.items) |w, s| {
        try w.layout(s);
    }
}

pub fn handle_event(self: *StackLayout, event: events.Event) !events.EventResult {
    // TODO: Fix focusing on Shift+Tab
    if (event == .FocusIn) {
        for (self.widgets.items, 0..) |w, i| {
            const res = try w.handle_event(.FocusIn);
            if (res == .Consumed) {
                self.focused = i;
                return .Consumed;
            }
        } else {
            return .Ignored;
        }
    }
    if (event == .FocusOut) {
        self.focused = null;
        return .Consumed;
    }

    if (self.focused == null) {
        if (try self.handle_event(.FocusIn) == .Ignored) {
            return .Ignored;
        }
    }

    const active = self.focused.?;
    const active_w = self.widgets.items[active];
    const res = try active_w.handle_event(event);

    switch (res) {
        .Consumed => return .Consumed,
        .Ignored => {
            switch (event) {
                .Key, .ShiftKey => |key| if (key == .Tab) {
                    const step: isize = if (event == .Key) 1 else -1;
                    var idx = @as(isize, @intCast(active)) + step;
                    while (0 <= idx and idx < self.widgets.items.len) : (idx += step) {
                        const uidx: usize = @intCast(idx);
                        const w = self.widgets.items[uidx];

                        if (try w.handle_event(.FocusIn) == .Consumed) {
                            self.focused = uidx;
                            _ = try active_w.handle_event(.FocusOut);
                            _ = try w.handle_event(event);
                            return .Consumed;
                        }
                    } else {
                        self.focused = null;
                        _ = try active_w.handle_event(.FocusOut);
                        return .Ignored;
                    }
                },
                else => {},
            }
        },
    }
    return .Ignored;
}
