const std = @import("std");
const Widget = @import("Widget.zig");
const Vec2 = @import("../Vec2.zig");
const Rect = @import("../Rect.zig");
const events = @import("../events.zig");
const Frame = @import("../render/Frame.zig");
const LayoutProperties = @import("LayoutProperties.zig");
const Constraints = @import("Constraints.zig");
const Theme = @import("../Theme.zig");

const Builder = struct {
    const VTable = struct {
        build: *const fn (context: *anyopaque) anyerror!Widget,

        needRebuild: *const fn (context: *anyopaque) bool,
    };

    context: *anyopaque,
    vtable: *const VTable,

    pub fn init(context: anytype) Builder {
        const T = @TypeOf(context);
        const ptr_info = @typeInfo(T);

        const vtable = struct {
            pub fn build(pointer: *anyopaque) anyerror!Widget {
                const self: T = @ptrCast(@alignCast(pointer));
                return ptr_info.Pointer.child.build(self);
            }

            pub fn needRebuild(pointer: *anyopaque) bool {
                const self: T = @ptrCast(@alignCast(pointer));
                return ptr_info.Pointer.child.needRebuild(self);
            }
        };

        return Builder{
            .context = context,
            .vtable = &.{
                .build = vtable.build,
                .needRebuild = vtable.needRebuild,
            },
        };
    }

    pub fn build(self: Builder) anyerror!Widget {
        return try self.vtable.build(self.context);
    }

    pub fn needRebuild(self: Builder) bool {
        return self.vtable.needRebuild(self.context);
    }
};

pub const StatefulWidget = @This();

allocator: std.mem.Allocator,

builder: Builder,

view: ?Widget,

pub fn create(allocator: std.mem.Allocator, builder: anytype) !*StatefulWidget {
    const self = try allocator.create(StatefulWidget);
    self.* = StatefulWidget{
        .allocator = allocator,
        .builder = Builder.init(builder),
        .view = try builder.build(),
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
    return try self.getOrInitView().layout(constraints);
}

pub fn handleEvent(self: *StatefulWidget, event: events.Event) !events.EventResult {
    return try self.view.?.handleEvent(event);
}

pub fn layoutProps(self: *StatefulWidget) LayoutProperties {
    return self.view.?.layoutProps();
}

pub fn getOrInitView(self: *StatefulWidget) Widget {
    if (self.builder.needRebuild()) {
        if (self.view) |view| view.destroy();
        self.view = self.builder.build() catch @panic("can't build the view");
    }
    return self.view.?;
}
