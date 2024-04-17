const std = @import("std");
const Vec2 = @import("../Vec2.zig");
const Rect = @import("../Rect.zig");
const events = @import("../events.zig");
const Frame = @import("../render/Frame.zig");

pub const Widget = @This();

context: *anyopaque,
vtable: *const VTable,

const VTable = struct {
    destroy: *const fn (context: *anyopaque) void,
    render: *const fn (context: *anyopaque, area: Rect, frame: *Frame) anyerror!void,
    desired_size: *const fn (context: *anyopaque, available: Vec2) anyerror!Vec2,
    layout: *const fn (context: *anyopaque, bounds: Vec2) anyerror!void,
    handle_event: *const fn (context: *anyopaque, event: events.Event) anyerror!events.EventResult,
};

pub fn init(context: anytype) Widget {
    const T = @TypeOf(context);
    const ptr_info = @typeInfo(T);

    const vtable = struct {
        pub fn destroy(pointer: *anyopaque) void {
            const self: T = @ptrCast(@alignCast(pointer));
            return ptr_info.Pointer.child.destroy(self);
        }

        pub fn render(pointer: *anyopaque, area: Rect, frame: *Frame) anyerror!void {
            const self: T = @ptrCast(@alignCast(pointer));
            return ptr_info.Pointer.child.render(self, area, frame);
        }

        pub fn desired_size(pointer: *anyopaque, available: Vec2) anyerror!Vec2 {
            const self: T = @ptrCast(@alignCast(pointer));
            return ptr_info.Pointer.child.desired_size(self, available);
        }

        pub fn layout(pointer: *anyopaque, bounds: Vec2) anyerror!void {
            const self: T = @ptrCast(@alignCast(pointer));
            return ptr_info.Pointer.child.layout(self, bounds);
        }

        pub fn handle_event(pointer: *anyopaque, event: events.Event) anyerror!events.EventResult {
            const self: T = @ptrCast(@alignCast(pointer));
            return ptr_info.Pointer.child.handle_event(self, event);
        }
    };

    return Widget{
        .context = context,
        .vtable = &.{
            .destroy = vtable.destroy,
            .render = vtable.render,
            .desired_size = vtable.desired_size,
            .layout = vtable.layout,
            .handle_event = vtable.handle_event,
        },
    };
}

pub fn destroy(self: Widget) void {
    return self.vtable.destroy(self.context);
}

pub fn render(self: Widget, area: Rect, frame: *Frame) !void {
    return self.vtable.render(self.context, area, frame);
}

pub fn desired_size(self: Widget, available: Vec2) anyerror!Vec2 {
    return try self.vtable.desired_size(self.context, available);
}

pub fn layout(self: Widget, bounds: Vec2) anyerror!void {
    try self.vtable.layout(self.context, bounds);
}

pub fn handle_event(self: Widget, event: events.Event) anyerror!events.EventResult {
    return self.vtable.handle_event(self.context, event);
}
