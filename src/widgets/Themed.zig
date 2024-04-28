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
    id: ?[]const u8 = null,

    theme: ?display.Theme = null,

    override: PartialTheme = .{},
};

const Themed = @This();

pub usingnamespace Widget.SingleChild.Mixin(Themed, .inner);
pub usingnamespace Widget.Base.Mixin(Themed, .widget_base);

widget_base: Widget.Base,

inner: Widget,

theme: PartialTheme,

pub fn create(config: Config, inner: anytype) !*Themed {
    const self = try internal.allocator.create(Themed);
    self.* = Themed{
        .widget_base = try Widget.Base.init(config.id),
        .inner = try Widget.fromAny(inner),
        .theme = .{},
    };
    if (config.theme) |theme| {
        self.setTheme(theme);
    }
    self.updateTheme(config.override);
    return self;
}

pub fn destroy(self: *Themed) void {
    self.widget_base.deinit();
    self.inner.destroy();
    internal.allocator.destroy(self);
}

pub fn widget(self: *Themed) Widget {
    return Widget.init(self);
}

pub fn setTheme(self: *Themed, theme: display.Theme) void {
    inline for (@typeInfo(display.Theme).Struct.fields) |field| {
        @field(self.theme, field.name) = @field(theme, field.name);
    }
}

pub fn updateTheme(self: *Themed, update: PartialTheme) void {
    inline for (@typeInfo(display.Theme).Struct.fields) |field| {
        const override = @field(update, field.name);
        if (override) |value| {
            @field(self.theme, field.name) = value;
        }
    }
}

pub fn render(self: *Themed, area: Rect, frame: Frame, theme: display.Theme) !void {
    var new_theme = theme;
    inline for (@typeInfo(display.Theme).Struct.fields) |field| {
        const part = @field(self.theme, field.name);
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
