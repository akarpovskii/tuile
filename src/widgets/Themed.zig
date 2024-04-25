const std = @import("std");
const internal = @import("../internal.zig");
const Widget = @import("Widget.zig");
const Vec2 = @import("../Vec2.zig");
const Rect = @import("../Rect.zig");
const events = @import("../events.zig");
const Frame = @import("../render/Frame.zig");
const LayoutProperties = @import("LayoutProperties.zig");
const Constraints = @import("Constraints.zig");
const display = @import("../display/display.zig");

const Themed = @This();

pub const PartialTheme = init_partial: {
    const original = @typeInfo(display.Theme).Struct.fields;
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
    theme: ?display.Theme = null,
    override: PartialTheme = .{},
};

inner: Widget,

partial_theme: PartialTheme,

pub fn create(config: Config, inner: anytype) !*Themed {
    var partial: PartialTheme = .{};
    if (config.theme) |theme| {
        inline for (@typeInfo(display.Theme).Struct.fields) |field| {
            @field(partial, field.name) = @field(theme, field.name);
        }
    }
    inline for (@typeInfo(display.Theme).Struct.fields) |field| {
        const part = &@field(partial, field.name);
        const override = @field(config.override, field.name);
        if (override) |value| {
            part.* = value;
        }
    }

    const self = try internal.allocator.create(Themed);
    self.* = Themed{
        .inner = try Widget.fromAny(inner),
        .partial_theme = partial,
    };
    return self;
}

pub fn destroy(self: *Themed) void {
    self.inner.destroy();
    internal.allocator.destroy(self);
}

pub fn widget(self: *Themed) Widget {
    return Widget.init(self);
}

pub fn render(self: *Themed, area: Rect, frame: Frame, theme: display.Theme) !void {
    var new_theme = theme;
    inline for (@typeInfo(display.Theme).Struct.fields) |field| {
        const part = @field(self.partial_theme, field.name);
        const new = &@field(new_theme, field.name);
        if (part) |value| {
            new.* = value;
        }
    }

    frame.setStyle(area, .{ .fg = new_theme.text_primary, .bg = new_theme.background });
    return try self.inner.render(area, frame, new_theme);
}

pub fn layout(self: *Themed, constraints: Constraints) !Vec2 {
    return try self.inner.layout(constraints);
}

pub fn handleEvent(self: *Themed, event: events.Event) !events.EventResult {
    return self.inner.handleEvent(event);
}

pub fn layoutProps(self: *Themed) LayoutProperties {
    return self.inner.layoutProps();
}

pub fn prepare(self: *Themed) !void {
    try self.inner.prepare();
}
