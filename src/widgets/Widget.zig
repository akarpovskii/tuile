const std = @import("std");
const Vec2 = @import("../Vec2.zig");
const Rect = @import("../Rect.zig");
const events = @import("../events.zig");
const Frame = @import("../render/Frame.zig");
const Sized = @import("Sized.zig");
const Constraints = @import("Constraints.zig");

pub const Widget = @This();

context: *anyopaque,

vtable: *const VTable,

const VTable = struct {
    destroy: *const fn (context: *anyopaque) void,
    render: *const fn (context: *anyopaque, area: Rect, frame: *Frame) anyerror!void,
    desired_size: *const fn (context: *anyopaque, available: Vec2) anyerror!Vec2,
    layout: *const fn (context: *anyopaque, constraints: Constraints) anyerror!void,
    handle_event: *const fn (context: *anyopaque, event: events.Event) anyerror!events.EventResult,

    min_width: *const fn (context: *anyopaque) u32,
    min_height: *const fn (context: *anyopaque) u32,
    max_width: *const fn (context: *anyopaque) u32,
    max_height: *const fn (context: *anyopaque) u32,
    preferred_width: *const fn (context: *anyopaque) ?u32,
    preferred_height: *const fn (context: *anyopaque) ?u32,
    flex: *const fn (context: *anyopaque) u32,
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

        pub fn layout(pointer: *anyopaque, constraints: Constraints) anyerror!void {
            const self: T = @ptrCast(@alignCast(pointer));
            return ptr_info.Pointer.child.layout(self, constraints);
        }

        pub fn handle_event(pointer: *anyopaque, event: events.Event) anyerror!events.EventResult {
            const self: T = @ptrCast(@alignCast(pointer));
            return ptr_info.Pointer.child.handle_event(self, event);
        }

        pub fn min_width(pointer: *anyopaque) u32 {
            const self: T = @ptrCast(@alignCast(pointer));
            return self.sized.min_width;
        }

        pub fn min_height(pointer: *anyopaque) u32 {
            const self: T = @ptrCast(@alignCast(pointer));
            return self.sized.min_height;
        }

        pub fn max_width(pointer: *anyopaque) u32 {
            const self: T = @ptrCast(@alignCast(pointer));
            return self.sized.max_width;
        }

        pub fn max_height(pointer: *anyopaque) u32 {
            const self: T = @ptrCast(@alignCast(pointer));
            return self.sized.max_height;
        }

        pub fn preferred_width(pointer: *anyopaque) ?u32 {
            const self: T = @ptrCast(@alignCast(pointer));
            return self.sized.preferred_width;
        }

        pub fn preferred_height(pointer: *anyopaque) ?u32 {
            const self: T = @ptrCast(@alignCast(pointer));
            return self.sized.preferred_height;
        }

        pub fn flex(pointer: *anyopaque) u32 {
            const self: T = @ptrCast(@alignCast(pointer));
            return self.sized.flex;
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

            .min_width = vtable.min_width,
            .min_height = vtable.min_height,
            .max_width = vtable.max_width,
            .max_height = vtable.max_height,
            .preferred_width = vtable.preferred_width,
            .preferred_height = vtable.preferred_height,
            .flex = vtable.flex,
        },
    };
}

pub inline fn destroy(self: Widget) void {
    return self.vtable.destroy(self.context);
}

pub inline fn render(self: Widget, area: Rect, frame: *Frame) !void {
    return self.vtable.render(self.context, area, frame);
}

pub inline fn desired_size(self: Widget, available: Vec2) anyerror!Vec2 {
    return try self.vtable.desired_size(self.context, available);
}

pub inline fn layout(self: Widget, constraints: Constraints) anyerror!void {
    try self.vtable.layout(self.context, constraints);
}

pub inline fn handle_event(self: Widget, event: events.Event) anyerror!events.EventResult {
    return self.vtable.handle_event(self.context, event);
}

pub inline fn min_width(self: Widget) u32 {
    return self.vtable.min_width(self.context);
}

pub inline fn min_height(self: Widget) u32 {
    return self.vtable.min_height(self.context);
}

pub inline fn max_width(self: Widget) u32 {
    return self.vtable.max_width(self.context);
}

pub inline fn max_height(self: Widget) u32 {
    return self.vtable.max_height(self.context);
}

pub inline fn preferred_width(self: Widget) ?u32 {
    return self.vtable.preferred_width(self.context);
}

pub inline fn preferred_height(self: Widget) ?u32 {
    return self.vtable.preferred_height(self.context);
}

pub inline fn flex(self: Widget) u32 {
    return self.vtable.flex(self.context);
}
