const Vec2 = @import("Vec2.zig");

const Rect = @This();

min: Vec2,

max: Vec2,

pub fn intersect(self: Rect, other: Rect) Rect {
    return Rect{
        .min = .{
            .x = @max(self.min.x, other.min.x),
            .y = @max(self.min.y, other.min.y),
        },
        .max = .{
            .x = @min(self.max.x, other.max.x),
            .y = @min(self.max.y, other.max.y),
        },
    };
}
