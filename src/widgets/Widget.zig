const std = @import("std");
const Vec2 = @import("../Vec2.zig");
const Rect = @import("../Rect.zig");
const Frame = @import("../render/Frame.zig");
const LayoutProperties = @import("LayoutProperties.zig");
const Constraints = @import("Constraints.zig");
const events = @import("../events.zig");
const display = @import("../display/display.zig");
const internal = @import("../internal.zig");

pub const Widget = @This();

context: *anyopaque,

vtable: *const VTable,

const VTable = struct {
    destroy: *const fn (context: *anyopaque) void,

    render: *const fn (context: *anyopaque, area: Rect, frame: Frame, theme: display.Theme) anyerror!void,

    layout: *const fn (context: *anyopaque, constraints: Constraints) anyerror!Vec2,

    handle_event: *const fn (context: *anyopaque, event: events.Event) anyerror!events.EventResult,

    layout_props: *const fn (context: *anyopaque) LayoutProperties,

    // Optional, widgets may not implement this method unless they have children.
    // In which case they must call prepare() on all of their children.
    // Tuile guarantees to call prepare() before any other method.
    prepare: *const fn (context: *anyopaque) anyerror!void,

    children: *const fn (context: *anyopaque) []Widget,

    id: *const fn (context: *anyopaque) ?[]const u8,
};

pub const Leaf = struct {
    pub fn Mixin(comptime Self: type) type {
        return struct {
            pub fn children(_: *Self) []Widget {
                return &.{};
            }
        };
    }
};

pub const SingleChild = struct {
    pub fn Mixin(comptime Self: type, comptime child: std.meta.FieldEnum(Self)) type {
        const child_field = std.meta.fieldInfo(Self, child);
        return struct {
            pub fn children(self: *Self) []Widget {
                return (&@field(self, child_field.name))[0..1];
            }
        };
    }
};

pub const MultiChild = struct {
    pub fn Mixin(comptime Self: type, comptime children_: std.meta.FieldEnum(Self)) type {
        const child_field = std.meta.fieldInfo(Self, children_);
        return struct {
            pub fn children(self: *Self) []Widget {
                if (@hasField(child_field.type, "items")) {
                    return @field(self, child_field.name).items;
                } else {
                    return @field(self, child_field.name);
                }
            }
        };
    }
};

pub const Base = struct {
    id: ?[]const u8,

    pub fn init(widget_id: ?[]const u8) !Base {
        return Base{
            .id = if (widget_id) |id_value| try internal.allocator.dupe(u8, id_value) else null,
        };
    }

    pub fn deinit(self: *Base) void {
        if (self.id) |v| {
            internal.allocator.free(v);
        }
    }

    pub fn Mixin(comptime Self: type, comptime base: std.meta.FieldEnum(Self)) type {
        const base_field = std.meta.fieldInfo(Self, base);
        return struct {
            pub fn id(self: *Self) ?[]const u8 {
                return @field(self, base_field.name).id;
            }
        };
    }
};

pub fn constructVTable(comptime T: type) VTable {
    const vtable = struct {
        pub fn destroy(pointer: *anyopaque) void {
            const self: *T = @ptrCast(@alignCast(pointer));
            return T.destroy(self);
        }

        pub fn render(pointer: *anyopaque, area: Rect, frame: Frame, theme: display.Theme) anyerror!void {
            std.debug.assert(area.max.x != std.math.maxInt(u32));
            std.debug.assert(area.max.y != std.math.maxInt(u32));
            const self: *T = @ptrCast(@alignCast(pointer));
            return T.render(self, area, frame, theme);
        }

        pub fn layout(pointer: *anyopaque, constraints: Constraints) anyerror!Vec2 {
            std.debug.assert(constraints.min_width <= constraints.max_width);
            std.debug.assert(constraints.min_height <= constraints.max_height);
            // std.debug.print("{any} - {any}\n", .{ *T, constraints });
            const self: *T = @ptrCast(@alignCast(pointer));
            const size = try T.layout(self, constraints);
            return size;
        }

        pub fn handleEvent(pointer: *anyopaque, event: events.Event) anyerror!events.EventResult {
            const self: *T = @ptrCast(@alignCast(pointer));
            return T.handleEvent(self, event);
        }

        pub fn layoutProps(pointer: *anyopaque) LayoutProperties {
            const self: *T = @ptrCast(@alignCast(pointer));
            return T.layoutProps(self);
        }

        pub fn prepare(pointer: *anyopaque) anyerror!void {
            const self: *T = @ptrCast(@alignCast(pointer));
            if (@hasDecl(T, "prepare")) {
                try T.prepare(self);
            }
        }

        pub fn children(pointer: *anyopaque) []Widget {
            const self: *T = @ptrCast(@alignCast(pointer));
            return T.children(self);
        }

        pub fn id(pointer: *anyopaque) ?[]const u8 {
            const self: *T = @ptrCast(@alignCast(pointer));
            return T.id(self);
        }
    };

    return VTable{
        .destroy = vtable.destroy,
        .render = vtable.render,
        .layout = vtable.layout,
        .handle_event = vtable.handleEvent,
        .layout_props = vtable.layoutProps,
        .prepare = vtable.prepare,
        .children = vtable.children,
        .id = vtable.id,
    };
}

pub fn init(context: anytype) Widget {
    const PtrT = @TypeOf(context);
    comptime if (@typeInfo(PtrT) != .Pointer) {
        @compileError("expected a widget pointer, got " ++ @typeName(PtrT));
    };
    const T = std.meta.Child(PtrT);

    const VTableImpl = struct {
        const vtable = constructVTable(T);
    };

    return Widget{
        .context = context,
        .vtable = &VTableImpl.vtable,
    };
}

pub inline fn destroy(self: Widget) void {
    return self.vtable.destroy(self.context);
}

pub inline fn render(self: Widget, area: Rect, frame: Frame, theme: display.Theme) !void {
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

pub inline fn prepare(self: Widget) anyerror!void {
    return self.vtable.prepare(self.context);
}

pub inline fn children(self: Widget) []Widget {
    return self.vtable.children(self.context);
}

pub inline fn id(self: Widget) ?[]const u8 {
    return self.vtable.id(self.context);
}

pub fn fromAny(any: anytype) anyerror!Widget {
    const ok = if (@typeInfo(@TypeOf(any)) == .ErrorUnion)
        try any
    else
        any;

    return if (@TypeOf(ok) == Widget)
        ok
    else
        ok.widget();
}

pub fn as(self: Widget, T: type) ?*T {
    const vtable_t = constructVTable(T);
    inline for (std.meta.fields(VTable)) |field| {
        if (@field(self.vtable, field.name) != @field(vtable_t, field.name)) {
            return null;
        }
    }
    return @ptrCast(@alignCast(self.context));
}

pub fn findById(self: Widget, widget_id: []const u8) ?Widget {
    if (self.id()) |w_id| {
        if (std.mem.eql(u8, w_id, widget_id)) {
            return self;
        }
    }
    for (self.children()) |child| {
        if (child.findById(widget_id)) |found| {
            return found;
        }
    }
    return null;
}
