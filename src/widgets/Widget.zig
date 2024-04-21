const std = @import("std");
const Vec2 = @import("../Vec2.zig");
const Rect = @import("../Rect.zig");
const events = @import("../events.zig");
const Frame = @import("../render/Frame.zig");
const LayoutProperties = @import("LayoutProperties.zig");
const Constraints = @import("Constraints.zig");
const Theme = @import("../Theme.zig");

pub const Widget = @This();

context: *anyopaque,

vtable: *const VTable,

const VTable = struct {
    destroy: *const fn (context: *anyopaque) void,

    render: *const fn (context: *anyopaque, area: Rect, frame: Frame, theme: Theme) anyerror!void,

    layout: *const fn (context: *anyopaque, constraints: Constraints) anyerror!Vec2,

    handle_event: *const fn (context: *anyopaque, event: events.Event) anyerror!events.EventResult,

    layout_props: *const fn (context: *anyopaque) LayoutProperties,
};

pub fn init(context: anytype) Widget {
    const T = @TypeOf(context);
    const ptr_info = @typeInfo(T);

    const vtable = struct {
        pub fn destroy(pointer: *anyopaque) void {
            const self: T = @ptrCast(@alignCast(pointer));
            return ptr_info.Pointer.child.destroy(self);
        }

        pub fn render(pointer: *anyopaque, area: Rect, frame: Frame, theme: Theme) anyerror!void {
            const self: T = @ptrCast(@alignCast(pointer));
            return ptr_info.Pointer.child.render(self, area, frame, theme);
        }

        pub fn layout(pointer: *anyopaque, constraints: Constraints) anyerror!Vec2 {
            std.debug.assert(constraints.min_width <= constraints.max_width);
            std.debug.assert(constraints.min_height <= constraints.max_height);
            const self: T = @ptrCast(@alignCast(pointer));
            const size = try ptr_info.Pointer.child.layout(self, constraints);
            // std.debug.print("{any}\n", .{T});
            return size;
        }

        pub fn handleEvent(pointer: *anyopaque, event: events.Event) anyerror!events.EventResult {
            const self: T = @ptrCast(@alignCast(pointer));
            return ptr_info.Pointer.child.handleEvent(self, event);
        }

        pub fn layoutProps(pointer: *anyopaque) LayoutProperties {
            const self: T = @ptrCast(@alignCast(pointer));
            return ptr_info.Pointer.child.layoutProps(self);
        }
    };

    return Widget{
        .context = context,
        .vtable = &.{
            .destroy = vtable.destroy,
            .render = vtable.render,
            .layout = vtable.layout,
            .handle_event = vtable.handleEvent,
            .layout_props = vtable.layoutProps,
        },
    };
}

pub inline fn destroy(self: Widget) void {
    return self.vtable.destroy(self.context);
}

pub inline fn render(self: Widget, area: Rect, frame: Frame, theme: Theme) !void {
    return self.vtable.render(self.context, area, frame, theme);
}

pub inline fn layout(self: Widget, constraints: Constraints) anyerror!Vec2 {
    return try self.vtable.layout(self.context, constraints);
}

pub inline fn handleEvent(self: Widget, event: events.Event) anyerror!events.EventResult {
    return self.vtable.handle_event(self.context, event);
}

pub inline fn layoutProps(self: Widget) LayoutProperties {
    return self.vtable.layout_props(self.context);
}
