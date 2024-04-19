const std = @import("std");

min_width: u32 = 0,

min_height: u32 = 0,

max_width: u32 = std.math.maxInt(u32),

max_height: u32 = std.math.maxInt(u32),

preferred_width: ?u32 = 0,

preferred_height: ?u32 = 0,

flex: u32 = 1,
