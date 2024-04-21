const std = @import("std");
const Widget = @import("Widget.zig");
const Vec2 = @import("../Vec2.zig");
const Rect = @import("../Rect.zig");
const events = @import("../events.zig");
const Frame = @import("../render/Frame.zig");
const LayoutProperties = @import("LayoutProperties.zig");
const Constraints = @import("Constraints.zig");
const Theme = @import("../Theme.zig");

const Themed = @This();

pub const PartialTheme = init_partial: {
    const original = @typeInfo(Theme).Struct.fields;
    const len = original.len;
    var partial: [len]std.builtin.Type.StructField = undefined;
    for (original, &partial) |orig, *part| {
        part.* = std.builtin.Type.StructField{
            .name = orig.name,
            .type = @Type(std.builtin.Type{ .Optional = .{ .child = orig.type } }),
            .default_value = &@as(?orig.type, null),
            .is_comptime = false,
            .alignment = orig.alignment,
        };
    }

    break :init_partial @Type(std.builtin.Type{
        .Struct = .{
            .layout = .auto,
            .fields = &partial,
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_tuple = false,
        },
    });
};

pub const Config = struct {
    theme: PartialTheme,
};

allocator: std.mem.Allocator,

inner: Widget,

partial_theme: PartialTheme,

pub fn create(allocator: std.mem.Allocator, config: Config, inner: anytype) !*Themed {
    const self = try allocator.create(Themed);
    self.* = Themed{
        .allocator = allocator,
        .inner = if (@TypeOf(inner) == Widget) inner else inner.widget(),
        .partial_theme = config.theme,
    };
    return self;
}

pub fn destroy(self: *Themed) void {
    self.inner.destroy();
    self.allocator.destroy(self);
}

pub fn widget(self: *Themed) Widget {
    return Widget.init(self);
}

pub fn render(self: *Themed, area: Rect, frame: Frame, theme: Theme) !void {
    var new_theme = theme;
    inline for (@typeInfo(Theme).Struct.fields) |field| {
        const part = @field(self.partial_theme, field.name);
        const new = &@field(new_theme, field.name);
        if (part) |value| {
            new.* = value;
        }
    }

    frame.set_style(area, .{ .fg = new_theme.foreground, .bg = new_theme.background });
    return try self.inner.render(area, frame, new_theme);
}

pub fn layout(self: *Themed, constraints: Constraints) !Vec2 {
    return try self.inner.layout(constraints);
}

pub fn handle_event(self: *Themed, event: events.Event) !events.EventResult {
    return self.inner.handle_event(event);
}

pub fn layout_props(self: *Themed) LayoutProperties {
    return self.inner.layout_props();
}
