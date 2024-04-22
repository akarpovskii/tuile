const std = @import("std");
const Color = @import("color.zig").Color;

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
