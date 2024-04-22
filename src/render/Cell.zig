const std = @import("std");
const display = @import("../display/display.zig");
const Cell = @This();

// Doesn't own the memory
symbol: ?[]const u8 = null,

fg: display.Color,

bg: display.Color,

effect: display.Style.Effect = .{},

pub fn setStyle(self: *Cell, style: display.Style) void {
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
