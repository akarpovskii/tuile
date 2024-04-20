const std = @import("std");
const Color = @import("../color.zig").Color;
const Style = @import("../Style.zig");

const Cell = @This();

// Doesn't own the memory
symbol: ?[]const u8 = null,

fg: Color,

bg: Color,

effect: Style.Effect = .{},

pub fn set_style(self: *Cell, style: Style) void {
    if (style.fg) |fg| {
        self.fg = fg;
    }
    if (style.bg) |bg| {
        self.bg = bg;
    }
    if (style.add_effect) |effect| {
        self.effect = self.effect.add(effect);
    }
    if (style.sub_effect) |effect| {
        self.effect = self.effect.sub(effect);
    }
}
