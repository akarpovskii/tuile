const std = @import("std");
const Color = @import("colors.zig").Color;

const Style = @This();

fg: ?Color = null,

bg: ?Color = null,

add_effect: ?Effect = null,

sub_effect: ?Effect = null,

pub const Effect = struct {
    highlight: bool = false,
    underline: bool = false,
    reverse: bool = false,
    blink: bool = false,
    dim: bool = false,
    bold: bool = false,
    italic: bool = false,

    pub fn add(self: Effect, other: Effect) Effect {
        var result: Effect = .{};
        inline for (std.meta.fields(Effect)) |field| {
            @field(result, field.name) = @field(self, field.name) or @field(other, field.name);
        }
        return result;
    }

    pub fn sub(self: Effect, other: Effect) Effect {
        var result: Effect = .{};
        inline for (std.meta.fields(Effect)) |field| {
            @field(result, field.name) = @field(self, field.name) and !@field(other, field.name);
        }
        return result;
    }
};

pub fn add(self: Style, other: Style) Style {
    var new = self;
    if (other.fg) |fg| new.fg = fg;
    if (other.bg) |bg| new.bg = bg;
    if (other.add_effect) |other_add| {
        if (new.add_effect) |*new_add| {
            new_add.* = new_add.add(other_add);
        } else {
            new.add_effect = other_add;
        }
    }
    if (other.sub_effect) |other_sub| {
        if (new.sub_effect) |*new_sub| {
            new_sub.* = new_sub.add(other_sub);
        } else {
            new.sub_effect = other_sub;
        }
    }
    return new;
}
