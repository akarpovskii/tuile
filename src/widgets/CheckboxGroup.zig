const std = @import("std");
const internal = @import("../internal.zig");
const Widget = @import("Widget.zig");
const Vec2 = @import("../Vec2.zig");
const Rect = @import("../Rect.zig");
const events = @import("../events.zig");
const Frame = @import("../render/Frame.zig");
const StackLayout = @import("StackLayout.zig");
const Checkbox = @import("Checkbox.zig");
const LayoutProperties = @import("LayoutProperties.zig");
const Constraints = @import("Constraints.zig");
const display = @import("../display.zig");
const callbacks = @import("callbacks.zig");

pub const Config = struct {
    id: ?[]const u8 = null,

    multiselect: bool = false,

    on_state_change: ?callbacks.Callback(.{ usize, bool }) = null,

    layout: LayoutProperties = .{},
};

pub const CheckboxGroup = @This();

pub usingnamespace Widget.SingleChild.Mixin(CheckboxGroup, .view);
pub usingnamespace Widget.Base.Mixin(CheckboxGroup, .widget_base);

widget_base: Widget.Base,

view: Widget,

multiselect: bool,

on_state_change: ?callbacks.Callback(.{ usize, bool }),

fn assertCheckbox(any: anytype) void {
    const T = @TypeOf(any);
    const info = @typeInfo(T);

    const Underlying = if (info == .ErrorUnion)
        info.ErrorUnion.payload
    else
        T;

    if (Underlying != *Checkbox) @compileError("expected type *Checkbox, found" ++ @typeName(Underlying));
}

fn assertCheckboxes(options: anytype) void {
    const info = @typeInfo(@TypeOf(options));
    if (info == .Struct and info.Struct.is_tuple) {
        // Tuples only support comptime indexing
        inline for (options) |opt| {
            assertCheckbox(opt);
        }
    } else {
        for (options) |opt| {
            assertCheckbox(opt);
        }
    }
}

pub fn create(config: Config, options: anytype) !*CheckboxGroup {
    assertCheckboxes(options);

    const self = try internal.allocator.create(CheckboxGroup);
    self.* = CheckboxGroup{
        .widget_base = try Widget.Base.init(config.id),
        .view = try Widget.fromAny(
            StackLayout.create(
                .{ .layout = config.layout },
                options,
            ),
        ),
        .multiselect = config.multiselect,
        .on_state_change = config.on_state_change,
    };

    const stack: *StackLayout = @ptrCast(@alignCast(self.view.context));
    if (stack.widgets.items.len > 0) {
        var found_checked = false;
        for (stack.widgets.items) |child| {
            var option: *Checkbox = @ptrCast(@alignCast(child.context));
            option.view.layout_properties.alignment.h = LayoutProperties.HAlign.left;

            if (!self.multiselect and option.checked) {
                if (found_checked) {
                    option.checked = false;
                }
                found_checked = true;
            }
        }
    }
    return self;
}

pub fn destroy(self: *CheckboxGroup) void {
    self.widget_base.deinit();
    self.view.destroy();
    internal.allocator.destroy(self);
}

pub fn widget(self: *CheckboxGroup) Widget {
    return Widget.init(self);
}

pub fn render(self: *CheckboxGroup, area: Rect, frame: Frame, theme: display.Theme) !void {
    try self.view.render(area, frame, theme);
}

pub fn layout(self: *CheckboxGroup, constraints: Constraints) !Vec2 {
    return try self.view.layout(constraints);
}

pub fn handleEvent(self: *CheckboxGroup, event: events.Event) !events.EventResult {
    if (!self.multiselect) {
        switch (event) {
            .char => |char| switch (char) {
                ' ' => {
                    const stack: *StackLayout = @ptrCast(@alignCast(self.view.context));
                    if (stack.focused) |focused| {
                        const focused_option: *Checkbox = @ptrCast(@alignCast(stack.widgets.items[focused].context));
                        if (focused_option.checked) {
                            return .ignored;
                        }
                    }
                },
                else => {},
            },
            else => {},
        }
    }

    const res = try self.view.handleEvent(event);
    if (res == .ignored) {
        return res;
    }

    switch (event) {
        .char => |char| switch (char) {
            ' ' => {
                // Safe - this option received and consumed the event
                const stack: *StackLayout = @ptrCast(@alignCast(self.view.context));
                const focused = stack.focused.?;
                const checked_option: *Checkbox = @ptrCast(@alignCast(stack.widgets.items[focused].context));
                if (self.on_state_change) |on_state_change| {
                    on_state_change.call(focused, checked_option.checked);
                }

                // Uncheck everything else
                if (!self.multiselect) {
                    for (stack.widgets.items, 0..) |*opt_w, idx| {
                        if (idx == focused) {
                            continue;
                        }
                        const option: *Checkbox = @ptrCast(@alignCast(opt_w.context));
                        if (option.checked) {
                            const nested_result = try option.handleEvent(.{ .char = ' ' });
                            std.debug.assert(nested_result == .consumed);
                            std.debug.assert(option.checked == false);

                            if (self.on_state_change) |on_state_change| {
                                on_state_change.call(idx, option.checked);
                            }
                        }
                    }
                }
                return .consumed;
            },
            else => {},
        },
        else => {},
    }
    return res;
}

pub fn layoutProps(self: *CheckboxGroup) LayoutProperties {
    return self.view.layoutProps();
}

pub fn prepare(self: *CheckboxGroup) !void {
    try self.view.prepare();
}
