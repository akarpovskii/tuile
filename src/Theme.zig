const std = @import("std");
const color = @import("color.zig");
const Color = color.Color;
const Rgb = color.Rgb;

foreground: Color = .{ .rgb = color.Rgb{ .r = 10, .g = 4, .b = 31 } },

background: Color = .{ .rgb = color.Rgb{ .r = 245, .g = 245, .b = 254 } },

primary: Color = .{ .rgb = color.Rgb{ .r = 67, .g = 44, .b = 228 } },

secondary: Color = .{ .rgb = color.Rgb{ .r = 239, .g = 131, .b = 215 } },

accent: Color = .{ .rgb = color.Rgb{ .r = 233, .g = 87, .b = 145 } },

cursor: Color = .{ .rgb = color.Rgb{ .r = 239, .g = 131, .b = 215 } },
