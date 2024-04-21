const std = @import("std");
const Widget = @import("Widget.zig");
const Vec2 = @import("../Vec2.zig");
const Rect = @import("../Rect.zig");
const events = @import("../events.zig");
const Frame = @import("../render/Frame.zig");
const LayoutProperties = @import("LayoutProperties.zig");
const Constraints = @import("Constraints.zig");
const Theme = @import("../Theme.zig");
const ChangeNotifier = @import("ChangeNotifier.zig");

pub const StatefulWidget = @This();

allocator: std.mem.Allocator,

builder: Builder,

view: ?Widget,

build_context: BuildContext,

const Builder = struct {
    const VTable = struct {
        build: *const fn (context: *anyopaque, build_context: *BuildContext) anyerror!Widget,
    };

    context: *anyopaque,
    vtable: *const VTable,

    pub fn init(context: anytype) Builder {
        const PtrT = @TypeOf(context);
        const ptr_info = @typeInfo(PtrT);
        comptime if (ptr_info != .Pointer) {
            @compileError("expected a state pointer, got " ++ @typeName(PtrT));
        };
        const T = ptr_info.Pointer.child;
        comptime if (!@hasDecl(T, "build")) {
            @compileError("view must provide method build(context: " ++ @typeName(PtrT) ++ ", build_context: *BuildContext) anyerror!Widget");
        };

        const vtable = struct {
            pub fn build(pointer: *anyopaque, build_context: *BuildContext) anyerror!Widget {
                const self: PtrT = @ptrCast(@alignCast(pointer));
                return T.build(self, build_context);
            }
        };

        return Builder{
            .context = context,
            .vtable = &.{
                .build = vtable.build,
            },
        };
    }

    pub fn build(self: Builder, build_context: *BuildContext) anyerror!Widget {
        return try self.vtable.build(self.context, build_context);
    }
};

pub const BuildContext = struct {
    state: *anyopaque,

    unique_id: usize,

    need_rebuild: bool,

    subscribe: *const fn (_: *BuildContext) anyerror!void,

    unsubscribe: *const fn (_: *BuildContext) void,

    pub fn init(state: anytype) BuildContext {
        const PtrT = @TypeOf(state);
        const ptr_info = @typeInfo(PtrT);
        comptime if (ptr_info != .Pointer) {
            @compileError("expected a state pointer, got " ++ @typeName(PtrT));
        };
        const T = ptr_info.Pointer.child;
        comptime if (!@hasDecl(T, "addListener") or !@hasDecl(T, "removeListener")) {
            @compileError("state must implement ChangeNotifier interface");
        };

        const erase_type = struct {
            pub fn subscribe(self: *BuildContext) !void {
                var state_ptr: PtrT = @ptrCast(@alignCast(self.state));
                try state_ptr.addListener(.{ .cb = BuildContext.onStateChange, .payload = self });
            }

            pub fn unsubscribe(self: *BuildContext) void {
                var state_ptr: PtrT = @ptrCast(@alignCast(self.state));
                state_ptr.removeListener(.{ .cb = BuildContext.onStateChange, .payload = self });
            }
        };

        return BuildContext{
            .state = state,
            .unique_id = typeId(T),
            .need_rebuild = true,
            .subscribe = erase_type.subscribe,
            .unsubscribe = erase_type.unsubscribe,
        };
    }

    pub fn read(self: *BuildContext, comptime T: type) !*T {
        const id = typeId(T);
        if (id == self.unique_id) {
            return @ptrCast(@alignCast(self.state));
        } else {
            return error.InvalidType;
        }
    }

    pub fn watch(self: *BuildContext, comptime T: type) !*T {
        try self.subscribe(self);
        return self.read(T);
    }

    fn typeId(comptime T: type) usize {
        const UniqueIdGenerator = struct {
            var name: u8 = @typeName(T)[0];

            inline fn id() usize {
                return @intFromPtr(&name);
            }
        };

        return UniqueIdGenerator.id();
    }

    fn onStateChange(ptr: ?*anyopaque) void {
        const self: *BuildContext = @ptrCast(@alignCast(ptr.?));
        self.need_rebuild = true;
    }
};

pub fn create(allocator: std.mem.Allocator, builder: anytype, state: anytype) !*StatefulWidget {
    const self = try allocator.create(StatefulWidget);
    self.* = StatefulWidget{
        .allocator = allocator,
        .builder = Builder.init(builder),
        .view = null,
        .build_context = BuildContext.init(state),
    };
    return self;
}

pub fn destroy(self: *StatefulWidget) void {
    if (self.view) |view| {
        view.destroy();
    }
    self.allocator.destroy(self);
}

pub fn widget(self: *StatefulWidget) Widget {
    return Widget.init(self);
}

pub fn render(self: *StatefulWidget, area: Rect, frame: Frame, theme: Theme) !void {
    try self.view.?.render(area, frame, theme);
}

pub fn layout(self: *StatefulWidget, constraints: Constraints) !Vec2 {
    return try self.view.?.layout(constraints);
}

pub fn handleEvent(self: *StatefulWidget, event: events.Event) !events.EventResult {
    return try self.view.?.handleEvent(event);
}

pub fn layoutProps(self: *StatefulWidget) LayoutProperties {
    return self.view.?.layoutProps();
}

pub fn prepare(self: *StatefulWidget) !void {
    if (self.build_context.need_rebuild) {
        if (self.view) |view| view.destroy();
        self.build_context.unsubscribe(&self.build_context);
        self.view = try self.builder.build(&self.build_context);
        self.build_context.need_rebuild = false;
    }
}
