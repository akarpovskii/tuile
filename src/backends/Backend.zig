const std = @import("std");
const Vec2 = @import("../Vec2.zig");
const events = @import("../events.zig");
const display = @import("../display/display.zig");

const Backend = @This();

context: *anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    destroy: *const fn (context: *anyopaque) void,
    poll_event: *const fn (context: *anyopaque) anyerror!?events.Event,
    refresh: *const fn (context: *anyopaque) anyerror!void,
    print_at: *const fn (context: *anyopaque, pos: Vec2, text: []const u8) anyerror!void,
    window_size: *const fn (context: *anyopaque) anyerror!Vec2,
    enable_effect: *const fn (context: *anyopaque, effect: display.Style.Effect) anyerror!void,
    disable_effect: *const fn (context: *anyopaque, effect: display.Style.Effect) anyerror!void,
    use_color: *const fn (context: *anyopaque, color: display.ColorPair) anyerror!void,
};

pub fn init(context: anytype) Backend {
    const T = @TypeOf(context);
    const ptr_info = @typeInfo(T);

    const vtable = struct {
        pub fn destroy(pointer: *anyopaque) void {
            const self: T = @ptrCast(@alignCast(pointer));
            return ptr_info.Pointer.child.destroy(self);
        }

        pub fn pollEvent(pointer: *anyopaque) anyerror!?events.Event {
            const self: T = @ptrCast(@alignCast(pointer));
            return ptr_info.Pointer.child.pollEvent(self);
        }

        pub fn refresh(pointer: *anyopaque) anyerror!void {
            const self: T = @ptrCast(@alignCast(pointer));
            return ptr_info.Pointer.child.refresh(self);
        }

        pub fn printAt(pointer: *anyopaque, pos: Vec2, text: []const u8) anyerror!void {
            const self: T = @ptrCast(@alignCast(pointer));
            return ptr_info.Pointer.child.printAt(self, pos, text);
        }

        pub fn windowSize(pointer: *anyopaque) anyerror!Vec2 {
            const self: T = @ptrCast(@alignCast(pointer));
            return ptr_info.Pointer.child.windowSize(self);
        }

        pub fn enableEffect(pointer: *anyopaque, effect: display.Style.Effect) anyerror!void {
            const self: T = @ptrCast(@alignCast(pointer));
            return ptr_info.Pointer.child.enableEffect(self, effect);
        }

        pub fn disableEffect(pointer: *anyopaque, effect: display.Style.Effect) anyerror!void {
            const self: T = @ptrCast(@alignCast(pointer));
            return ptr_info.Pointer.child.disableEffect(self, effect);
        }

        pub fn useColor(pointer: *anyopaque, color: display.ColorPair) anyerror!void {
            const self: T = @ptrCast(@alignCast(pointer));
            return ptr_info.Pointer.child.useColor(self, color);
        }
    };

    return Backend{
        .context = context,
        .vtable = &.{
            .destroy = vtable.destroy,
            .poll_event = vtable.pollEvent,
            .refresh = vtable.refresh,
            .print_at = vtable.printAt,
            .window_size = vtable.windowSize,
            .enable_effect = vtable.enableEffect,
            .disable_effect = vtable.disableEffect,
            .use_color = vtable.useColor,
        },
    };
}

pub fn destroy(self: Backend) void {
    return self.vtable.destroy(self.context);
}

pub fn pollEvent(self: Backend) anyerror!?events.Event {
    return self.vtable.poll_event(self.context);
}

pub fn refresh(self: Backend) anyerror!void {
    return self.vtable.refresh(self.context);
}

pub fn printAt(self: Backend, pos: Vec2, text: []const u8) anyerror!void {
    return self.vtable.print_at(self.context, pos, text);
}

pub fn windowSize(self: Backend) anyerror!Vec2 {
    return self.vtable.window_size(self.context);
}

pub fn enableEffect(self: Backend, effect: display.Style.Effect) anyerror!void {
    return self.vtable.enable_effect(self.context, effect);
}

pub fn disableEffect(self: Backend, effect: display.Style.Effect) anyerror!void {
    return self.vtable.disable_effect(self.context, effect);
}

pub fn useColor(self: Backend, color: display.ColorPair) anyerror!void {
    return self.vtable.use_color(self.context, color);
}
