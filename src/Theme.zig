const std = @import("std");
const color = @import("color.zig");
const Color = color.Color;
const Rgb = color.Rgb;

foreground: Color = .{ .dark = .black },

background: Color = .{ .rgb = Rgb.white() },

primary: Color = .{ .dark = .black },

secondary: Color = .{ .rgb = Rgb.white() },

accent: Color = .{ .dark = .black },

cursor: Color = .{ .dark = .black },
