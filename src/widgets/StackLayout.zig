const std = @import("std");
const internal = @import("../internal.zig");
const Widget = @import("Widget.zig");
const Vec2 = @import("../Vec2.zig");
const Rect = @import("../Rect.zig");
const events = @import("../events.zig");
const Frame = @import("../render/Frame.zig");
const LayoutProperties = @import("LayoutProperties.zig");
const Constraints = @import("Constraints.zig");
const display = @import("../display.zig");

pub const Orientation = enum {
    vertical,
    horizontal,
};

pub const Config = struct {
    id: ?[]const u8 = null,

    orientation: Orientation = .vertical,

    layout: LayoutProperties = .{},
};

pub const StackLayout = @This();

pub usingnamespace Widget.MultiChild.Mixin(StackLayout, .widgets);
pub usingnamespace Widget.Base.Mixin(StackLayout, .widget_base);

widget_base: Widget.Base,

widgets: std.ArrayListUnmanaged(Widget),

widget_sizes: std.ArrayListUnmanaged(Vec2),

orientation: Orientation,

focused: ?usize = null,

layout_properties: LayoutProperties,

fn createWidgets(children: anytype) !std.ArrayListUnmanaged(Widget) {
    var widgets = std.ArrayListUnmanaged(Widget){};

    const info = @typeInfo(@TypeOf(children));
    if (info == .Struct and info.Struct.is_tuple) {
        // Tuples only support comptime indexing
        inline for (children) |child| {
            try widgets.append(internal.allocator, try Widget.fromAny(child));
        }
    } else {
        for (children) |child| {
            try widgets.append(internal.allocator, try Widget.fromAny(child));
        }
    }
    return widgets;
}

pub fn create(config: Config, children: anytype) !*StackLayout {
    const widgets = try createWidgets(children);

    const self = try internal.allocator.create(StackLayout);
    self.* = StackLayout{
        .widget_base = try Widget.Base.init(config.id),
        .widgets = widgets,
        .widget_sizes = std.ArrayListUnmanaged(Vec2){},
        .orientation = config.orientation,
        .layout_properties = config.layout,
    };
    return self;
}

pub fn addChild(self: *StackLayout, child: anytype) !void {
    try self.widgets.append(internal.allocator, try Widget.fromAny(child));
}

pub fn removeChild(self: *StackLayout, child: Widget) error{NotFound}!Widget {
    for (0..self.widgets.items.len) |i| {
        if (self.widgets.items[i].context == child.context) {
            if (i == self.focused) {
                self.focused = null;
            }
            return self.widgets.orderedRemove(i);
        }
    }
    return error.NotFound;
}

pub fn destroy(self: *StackLayout) void {
    self.widget_base.deinit();
    for (self.widgets.items) |w| {
        w.destroy();
    }
    self.widgets.deinit(internal.allocator);
    self.widget_sizes.deinit(internal.allocator);
    internal.allocator.destroy(self);
}

pub fn widget(self: *StackLayout) Widget {
    return Widget.init(self);
}

pub fn render(self: *StackLayout, area: Rect, frame: Frame, theme: display.Theme) !void {
    var cursor = area.min;

    for (self.widgets.items, self.widget_sizes.items) |w, s| {
        const props = w.layoutProps();
        const alignment = props.alignment;

        var widget_area = Rect{
            .min = cursor,
            .max = cursor.add(s),
        };

        switch (self.orientation) {
            .vertical => widget_area = area.alignH(alignment.h, widget_area),
            .horizontal => widget_area = area.alignV(alignment.v, widget_area),
        }

        try w.render(widget_area, frame.withArea(widget_area), theme);
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
        .vertical => return try self.layoutImpl(constraints, .vertical),
        .horizontal => return try self.layoutImpl(constraints, .horizontal),
    }
}

pub fn layoutImpl(self: *StackLayout, constraints: Constraints, comptime orientation: Orientation) !Vec2 {
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
    try self.widget_sizes.resize(internal.allocator, self.widgets.items.len);

    var flex_indices = std.ArrayList(usize).init(internal.allocator);
    defer flex_indices.deinit();
    var fixed_indices = std.ArrayList(usize).init(internal.allocator);
    defer fixed_indices.deinit();

    for (self.widgets.items, 0..) |w, idx| {
        const props = w.layoutProps();
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
        var size = try w.layout(w_cons);
        @field(size, cross) = @min(@field(size, cross), @field(constraints, max_cross));
        @field(size, main) = @min(@field(size, main), @field(constraints, max_main));

        self.widget_sizes.items[idx] = size;
        fixed_size += @field(size, main);
        @field(self_size, main) += @field(size, main);
        @field(self_size, cross) = @max(@field(self_size, cross), @field(size, cross));
    }

    var total_flex: u32 = 0;
    for (flex_indices.items) |idx| {
        const w = self.widgets.items[idx];
        const props = w.layoutProps();
        total_flex += props.flex;
    }
    var remaining = @field(constraints, max_main) -| fixed_size;
    for (flex_indices.items) |idx| {
        const w = self.widgets.items[idx];
        const props = w.layoutProps();
        const flex = props.flex;
        const weight = @as(f64, @floatFromInt(flex)) / @as(f64, @floatFromInt(total_flex));
        const main_size_f = @as(f64, @floatFromInt(remaining)) * weight;
        const widget_main_size = @as(u32, @intFromFloat(@round(main_size_f)));

        var w_cons = Constraints{};
        @field(w_cons, min_main) = widget_main_size;
        @field(w_cons, max_main) = widget_main_size;
        @field(w_cons, max_cross) = @field(constraints, max_cross);
        var size = try w.layout(w_cons);
        @field(size, cross) = @min(@field(size, cross), @field(constraints, max_cross));
        @field(size, main) = widget_main_size;
        if (@field(size, cross) == std.math.maxInt(u32)) {
            @field(size, cross) = @field(self_size, cross);
        }

        self.widget_sizes.items[idx] = size;
        @field(self_size, main) += @field(size, main);
        @field(self_size, cross) = @max(@field(self_size, cross), @field(size, cross));

        remaining -= widget_main_size;
        total_flex -= flex;
    }
    if (flex_indices.items.len > 0) std.debug.assert(remaining == 0);

    @field(self_size, cross) = std.math.clamp(
        @field(self_size, cross),
        @field(constraints, min_cross),
        @field(constraints, max_cross),
    );

    return self_size;
}

// https://github.com/ziglang/zig/pull/19786
fn handleEvent2(self: *StackLayout, event: events.Event) anyerror!events.EventResult {
    return self.handleEvent(event);
}

pub fn handleEvent(self: *StackLayout, event: events.Event) !events.EventResult {
    if (event == .focus_in) {
        var iter = WidgetsIterator.inDirection(self.widgets.items, event.focus_in);
        return self.focusOnNext(&iter, event.focus_in);
    }
    if (event == .focus_out) {
        self.focused = null;
        return .consumed;
    }

    if (self.focused == null or self.focused.? > self.widgets.items.len) {
        // If nothing is focused, pressing Tab or Shift+Tab
        // technically generates two events: FocusIn and Key/ShiftKey.
        // If this is the case, we only need to pass down FocusIn to avoid changing the focus twice.
        var supress_further: bool = undefined;
        var direction: events.FocusDirection = undefined;

        switch (event) {
            .key, .shift_key => |key| if (key == .Tab) {
                supress_further = true;
                direction = if (event == .key) .front else .back;
            },
            else => {
                supress_further = false;
                direction = .front;
            },
        }

        if (try self.handleEvent2(.{ .focus_in = direction }) == .ignored) {
            return .ignored;
        }
        if (supress_further) {
            return .consumed;
        }
    }

    const active = self.focused.?;
    const active_w = self.widgets.items[active];

    switch (try active_w.handleEvent(event)) {
        .consumed => return .consumed,
        .ignored => {
            switch (event) {
                .key, .shift_key => |key| if (key == .Tab) {
                    const direction: events.FocusDirection = if (event == .key) .front else .back;

                    var iter = WidgetsIterator.inDirection(self.widgets.items, direction);
                    iter.current = @as(isize, @intCast(active)) + iter.step;

                    const focused = self.focusOnNext(&iter, direction);
                    _ = try active_w.handleEvent(.focus_out);
                    return focused;
                },
                else => {},
            }
        },
    }
    return .ignored;
}

fn focusOnNext(self: *StackLayout, iter: *WidgetsIterator, direction: events.FocusDirection) !events.EventResult {
    while (iter.peek()) |w| : (_ = iter.next()) {
        if (try w.handleEvent(.{ .focus_in = direction }) == .consumed) {
            self.focused = @intCast(iter.current);
            return .consumed;
        }
    } else {
        self.focused = null;
        return .ignored;
    }
}

const WidgetsIterator = struct {
    widgets: []Widget,

    step: isize,

    current: isize,

    pub fn inDirection(widgets: []Widget, direction: events.FocusDirection) WidgetsIterator {
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

pub fn layoutProps(self: *StackLayout) LayoutProperties {
    return self.layout_properties;
}

pub fn prepare(self: *StackLayout) !void {
    for (self.widgets.items) |w| {
        try w.prepare();
    }
}
