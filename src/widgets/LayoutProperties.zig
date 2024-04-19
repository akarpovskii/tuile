const std = @import("std");

min_width: u32 = 0,

min_height: u32 = 0,

max_width: u32 = std.math.maxInt(u32),

max_height: u32 = std.math.maxInt(u32),

flex: u32 = 0,

alignment: Alignment = .center,

pub const Alignment = enum {
    start,
    end,
    center,
};
