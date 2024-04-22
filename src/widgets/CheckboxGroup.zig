const std = @import("std");
const internal = @import("../internal.zig");
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
const Theme = @import("../Theme.zig");

pub const Config = struct {
    multiselect: bool = false,

    layout: LayoutProperties = .{},
};

pub const CheckboxGroup = @This();

view: *StackLayout,

multiselect: bool,

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
        .view = try StackLayout.create(
            .{ .layout = config.layout },
            options,
        ),
        .multiselect = config.multiselect,
    };
    return self;
}

pub fn destroy(self: *CheckboxGroup) void {
    self.view.destroy();
    internal.allocator.destroy(self);
}

pub fn widget(self: *CheckboxGroup) Widget {
    return Widget.init(self);
}

pub fn render(self: *CheckboxGroup, area: Rect, frame: Frame, theme: Theme) !void {
    try self.view.render(area, frame, theme);
}

pub fn layout(self: *CheckboxGroup, constraints: Constraints) !Vec2 {
    return try self.view.layout(constraints);
}

pub fn handleEvent(self: *CheckboxGroup, event: events.Event) !events.EventResult {
    const res = try self.view.handleEvent(event);
    if (res == .ignored) {
        return res;
    }

    switch (event) {
        .char => |char| switch (char) {
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
