const std = @import("std");
const Vec2 = @import("../Vec2.zig");
const Sized = @import("Sized.zig");

const Constraints = @This();

min_width: u32 = 0,

min_height: u32 = 0,

max_width: u32 = std.math.maxInt(u32),

max_height: u32 = std.math.maxInt(u32),

pub fn apply(self: Constraints, size: Vec2) Vec2 {
    return .{
        .x = self.clamp_width(size.x),
        .y = self.clamp_height(size.y),
    };
}

pub fn clamp_width(self: Constraints, value: u32) u32 {
    return std.math.clamp(value, self.min_width, self.max_width);
}

pub fn clamp_height(self: Constraints, value: u32) u32 {
    return std.math.clamp(value, self.min_height, self.max_height);
}

pub fn from_sized(sized: Sized) Constraints {
    return .{
        .min_width = sized.min_width,
        .min_height = sized.min_height,
        .max_width = sized.max_width,
        .max_height = sized.max_height,
    };
}
