const std = @import("std");
const Color = @import("color.zig").Color;

const Style = @This();

fg: ?Color,

bg: ?Color,

add_effect: ?Effect,

sub_effect: ?Effect,

pub const Effect = enum {
    none,
    highlight,
    underline,
    reverse,
    blink,
    dim,
    bold,
};
