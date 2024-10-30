const std = @import("std");
const Vec2u = @import("../vec2.zig").Vec2u;
const Rect = @import("../rect.zig").Rect;
const Frame = @import("../render/Frame.zig");
const LayoutProperties = @import("LayoutProperties.zig");
const Constraints = @import("Constraints.zig");
const events = @import("../events.zig");
const display = @import("../display.zig");
const internal = @import("../internal.zig");

pub const Widget = @This();

context: *anyopaque,

vtable: *const VTable,

const VTable = struct {
    /// Tuile owns the widgets and calls `destroy` when needed.
    destroy: *const fn (context: *anyopaque) void,

    /// A unique identifier of a widget to be used in `Tuile.findById` and `Widget.findById`.
    id: *const fn (context: *anyopaque) ?[]const u8,

    /// See `Leaf`, `SingleChild`, `MultiChild`.
    children: *const fn (context: *anyopaque) []Widget,

    /// Layout properties of a widget
    layout_props: *const fn (context: *anyopaque) LayoutProperties,

    /// Optional, widgets may not implement this method unless they have children.
    /// In which case they must call prepare() on all of their children.
    /// Tuile guarantees to call `prepare` before any other method in the event loop.
    prepare: *const fn (context: *anyopaque) anyerror!void,

    /// Constraints go down, sizes go up, parent sets position.
    /// * A widget receives its constraints from the parent.
    /// * Then it goes over its children, calculates their constraints,
    ///   and asks each one what size it wants to be.
    /// * Then it positions each children
    /// * Finally, it calculates its own size and returns the size to the parent.
    ///
    /// * A widget must satisfy the constraints given to it by its parent.
    /// * A widget doesn't decide its position on the screen.
    /// * A parent might set `max_width` or `max_height` to std.math.maxInt(u32)
    ///   if it doesn't have anough information to align the child. In which case
    ///   the child should tell the parent a finite desired size.
    layout: *const fn (context: *anyopaque, constraints: Constraints) anyerror!Vec2u,

    /// Widgets must draw themselves inside of `area`. Writes outside of `area` are ignored.
    /// `theme` is the currently used theme which can be overridden by the `Themed` widget.
    /// `render` is guaranteed to be called after `layout`.
    render: *const fn (context: *anyopaque, area: Rect(i32), frame: Frame, theme: display.Theme) anyerror!void,

    /// If a widget returns .consumed, the event is considered fulfilled and is not propagated further.
    /// If a widget returns .ignored, the event is passed to the next widget in the tree.
    handle_event: *const fn (context: *anyopaque, event: events.Event) anyerror!events.EventResult,
};

/// Marks a widget with no children.
/// To reduce the boilerplate, widgets can use the inner `Mixin` to generate the `children` method.
/// To mark a widget add the following:
/// `pub usingnamespace Leaf.Mixin(@This());`
/// See `Label` for an example.
pub const Leaf = struct {
    pub fn Mixin(comptime Self: type) type {
        return struct {
            pub fn children(_: *Self) []Widget {
                return &.{};
            }
        };
    }
};

/// Marks a widget with one child
/// To reduce the boilerplate, widgets can use the inner `Mixin` to generate the `children` method.
/// To mark a widget add the following:
/// `pub usingnamespace SingleChild.Mixin(@This(), .child_field_name);`
/// where `child_field_name` has type Widget.
/// See `Block` for an example.
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

/// Marks a widget with multiple children.
/// To reduce the boilerplate, widgets can use the inner `Mixin` to generate the `children` method.
/// To mark a widget add the following:
/// `pub usingnamespace MultiChild.Mixin(@This(), .child_field_name);`
/// where `child_field_name` must either be `[]Widget`, or it must have `items` field of type `Widget[]` (like std.ArrayList).
/// See `StackLayout` for an example.
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
    /// A unique identifier of the widget to be used in `Tuile.findById` and `Widget.findById`.
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

        pub fn render(pointer: *anyopaque, area: Rect(i32), frame: Frame, theme: display.Theme) anyerror!void {
            std.debug.assert(area.max.x != std.math.maxInt(u32));
            std.debug.assert(area.max.y != std.math.maxInt(u32));
            const self: *T = @ptrCast(@alignCast(pointer));
            return T.render(self, area, frame, theme);
        }

        pub fn layout(pointer: *anyopaque, constraints: Constraints) anyerror!Vec2u {
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

    const vtable = comptime constructVTable(T);

    return Widget{
        .context = context,
        .vtable = &vtable,
    };
}

pub inline fn destroy(self: Widget) void {
    return self.vtable.destroy(self.context);
}

pub inline fn render(self: Widget, area: Rect(i32), frame: Frame, theme: display.Theme) !void {
    return self.vtable.render(self.context, area, frame, theme);
}

pub inline fn layout(self: Widget, constraints: Constraints) anyerror!Vec2u {
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

/// Does a "dynamic cast" by comparing the vtables of `self` and `T`.
/// If all the fields are equal, returns *T, otherwise returns null.
/// For this method to work, widgets are encouraged to delegate
/// the vtable creation to `Widget.init`.
pub fn as(self: Widget, T: type) ?*T {
    const vtable_t = constructVTable(T);
    inline for (std.meta.fields(VTable)) |field| {
        if (@field(self.vtable, field.name) != @field(vtable_t, field.name)) {
            return null;
        }
    }
    return @ptrCast(@alignCast(self.context));
}

/// Searches for a child (or self) with `id` equals `widget_id`.
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
