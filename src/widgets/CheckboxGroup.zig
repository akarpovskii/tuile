const std = @import("std");
const Widget = @import("Widget.zig");
const Vec2 = @import("../Vec2.zig");
const Rect = @import("../Rect.zig");
const events = @import("../events.zig");
const Frame = @import("../render/Frame.zig");
const Style = @import("../Style.zig");
const StackLayout = @import("StackLayout.zig");
const Checkbox = @import("Checkbox.zig");
const LayoutProperties = @import("LayoutProperties.zig");
const Constraints = @import("Constraints.zig");

pub const Config = struct {
    multiselect: bool = false,

    layout: LayoutProperties = .{},
};

pub const CheckboxGroup = @This();

allocator: std.mem.Allocator,

view: *StackLayout,

multiselect: bool,

pub fn create(allocator: std.mem.Allocator, config: Config, options: anytype) !*CheckboxGroup {
    inline for (options) |opt| {
        const T = @TypeOf(opt);
        if (T != *Checkbox) @compileError("expected type *Checkbox, found" ++ @typeName(T));
    }
    const self = try allocator.create(CheckboxGroup);
    self.* = CheckboxGroup{
        .allocator = allocator,
        .view = try StackLayout.create(
            allocator,
            .{ .layout = config.layout },
            options,
        ),
        .multiselect = config.multiselect,
    };
    return self;
}

pub fn destroy(self: *CheckboxGroup) void {
    self.view.destroy();
    self.allocator.destroy(self);
}

pub fn widget(self: *CheckboxGroup) Widget {
    return Widget.init(self);
}

pub fn render(self: *CheckboxGroup, area: Rect, frame: Frame) !void {
    try self.view.render(area, frame);
}

pub fn layout(self: *CheckboxGroup, constraints: Constraints) !Vec2 {
    return try self.view.layout(constraints);
}

pub fn handle_event(self: *CheckboxGroup, event: events.Event) !events.EventResult {
    const res = try self.view.handle_event(event);
    if (res == .Ignored) {
        return res;
    }

    switch (event) {
        .Char => |char| switch (char) {
            ' ' => {
                if (!self.multiselect) {
                    // This option received the event
                    const focused = self.view.focused.?;
                    // Uncheck everything else
                    for (self.view.widgets.items, 0..) |*opt_w, idx| {
                        if (idx == focused) {
                            continue;
                        }
                        const option: *Checkbox = @ptrCast(@alignCast(opt_w.context));
                        if (option.checked) {
                            option.*.checked = false;
                        }
                    }
                }
                return .Consumed;
            },
            else => {},
        },
        else => {},
    }
    return res;
}

pub fn layout_props(self: *CheckboxGroup) LayoutProperties {
    return self.view.layout_props();
}
