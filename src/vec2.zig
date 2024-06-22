const std = @import("std");

pub fn Vec2(T: type) type {
    return struct {
        const Self = @This();

        x: T,
        y: T,

        pub fn zero() Self {
            return .{ .x = 0, .y = 0 };
        }

        pub fn add(a: Self, b: Self) Self {
            return .{
                .x = a.x + b.x,
                .y = a.y + b.y,
            };
        }

        pub fn addEq(self: *Self, b: Self) void {
            self.*.x += b.x;
            self.*.y += b.y;
        }

        pub fn sub(a: Self, b: Self) Self {
            return .{
                .x = a.x - b.x,
                .y = a.y - b.y,
            };
        }

        pub fn subEq(self: *Self, b: Self) void {
            self.*.x -= b.x;
            self.*.y -= b.y;
        }

        pub fn mul(a: Self, k: T) Self {
            return .{
                .x = a.x * k,
                .y = a.y * k,
            };
        }

        pub fn mulEq(self: *Self, k: T) void {
            self.*.x *= k;
            self.*.y *= k;
        }

        pub fn divFloor(self: Self, denominator: T) Self {
            return .{
                .x = @divFloor(self.x, denominator),
                .y = @divFloor(self.y, denominator),
            };
        }

        pub fn transpose(self: Self) Self {
            return .{ .x = self.y, .y = self.x };
        }

        pub fn as(self: Self, U: type) Vec2(U) {
            return .{ .x = @intCast(self.x), .y = @intCast(self.y) };
        }
    };
}

pub const Vec2u = Vec2(u32);
pub const Vec2i = Vec2(i32);
