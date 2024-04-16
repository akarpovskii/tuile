const std = @import("std");
const Vec2 = @import("../Vec2.zig");
const events = @import("../events.zig");
const Style = @import("../Style.zig");

const Backend = @This();

context: *anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    deinit: *const fn (context: *anyopaque) anyerror!void,
    poll_event: *const fn (context: *anyopaque) anyerror!?events.Event,
    refresh: *const fn (context: *anyopaque) anyerror!void,
    print_at: *const fn (context: *anyopaque, pos: Vec2, text: []const u8) anyerror!void,
    window_size: *const fn (context: *anyopaque) anyerror!Vec2,
    enable_effect: *const fn (context: *anyopaque, effect: Style.Effect) anyerror!void,
    disable_effect: *const fn (context: *anyopaque, effect: Style.Effect) anyerror!void,
};

pub fn init(context: anytype) Backend {
    const T = @TypeOf(context);
    const ptr_info = @typeInfo(T);

    const vtable = struct {
        pub fn deinit(pointer: *anyopaque) anyerror!void {
            const self: T = @ptrCast(@alignCast(pointer));
            return ptr_info.Pointer.child.deinit(self);
        }

        pub fn poll_event(pointer: *anyopaque) anyerror!?events.Event {
            const self: T = @ptrCast(@alignCast(pointer));
            return ptr_info.Pointer.child.poll_event(self);
        }

        pub fn refresh(pointer: *anyopaque) anyerror!void {
            const self: T = @ptrCast(@alignCast(pointer));
            return ptr_info.Pointer.child.refresh(self);
        }

        pub fn print_at(pointer: *anyopaque, pos: Vec2, text: []const u8) anyerror!void {
            const self: T = @ptrCast(@alignCast(pointer));
            return ptr_info.Pointer.child.print_at(self, pos, text);
        }

        pub fn window_size(pointer: *anyopaque) anyerror!Vec2 {
            const self: T = @ptrCast(@alignCast(pointer));
            return ptr_info.Pointer.child.window_size(self);
        }

        pub fn enable_effect(pointer: *anyopaque, effect: Style.Effect) anyerror!void {
            const self: T = @ptrCast(@alignCast(pointer));
            return ptr_info.Pointer.child.enable_effect(self, effect);
        }

        pub fn disable_effect(pointer: *anyopaque, effect: Style.Effect) anyerror!void {
            const self: T = @ptrCast(@alignCast(pointer));
            return ptr_info.Pointer.child.disable_effect(self, effect);
        }
    };

    return Backend{
        .context = context,
        .vtable = &.{
            .deinit = vtable.deinit,
            .poll_event = vtable.poll_event,
            .refresh = vtable.refresh,
            .print_at = vtable.print_at,
            .window_size = vtable.window_size,
            .enable_effect = vtable.enable_effect,
            .disable_effect = vtable.disable_effect,
        },
    };
}

pub fn deinit(self: Backend) anyerror!void {
    return self.vtable.deinit(self.context);
}

pub fn poll_event(self: Backend) anyerror!?events.Event {
    return self.vtable.poll_event(self.context);
}

pub fn refresh(self: Backend) anyerror!void {
    return self.vtable.refresh(self.context);
}

pub fn print_at(self: Backend, pos: Vec2, text: []const u8) anyerror!void {
    return self.vtable.print_at(self.context, pos, text);
}

pub fn window_size(self: Backend) anyerror!Vec2 {
    return self.vtable.window_size(self.context);
}

pub fn enable_effect(self: Backend, effect: Style.Effect) anyerror!void {
    return self.vtable.enable_effect(self.context, effect);
}

pub fn disable_effect(self: Backend, effect: Style.Effect) anyerror!void {
    return self.vtable.disable_effect(self.context, effect);
}
