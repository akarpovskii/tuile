const std = @import("std");
const Vec2 = @import("../Vec2.zig");
const LayoutProperties = @import("LayoutProperties.zig");

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

pub fn from_props(props: LayoutProperties) Constraints {
    return .{
        .min_width = props.min_width,
        .min_height = props.min_height,
        .max_width = props.max_width,
        .max_height = props.max_height,
    };
}
