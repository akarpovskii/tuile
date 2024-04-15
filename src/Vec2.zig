const std = @import("std");

const Vec2 = @This();

x: u32,
y: u32,

pub fn zero() Vec2 {
    return .{ .x = 0, .y = 0 };
}

pub fn add(a: Vec2, b: Vec2) Vec2 {
    return .{
        .x = a.x + b.x,
        .y = a.y + b.y,
    };
}

pub fn addEq(self: *Vec2, b: Vec2) void {
    self.*.x += b.x;
    self.*.y += b.y;
}

pub fn sub(a: Vec2, b: Vec2) Vec2 {
    return .{
        .x = a.x - b.x,
        .y = a.y - b.y,
    };
}

pub fn subEq(self: *Vec2, b: Vec2) void {
    self.*.x -= b.x;
    self.*.y -= b.y;
}

pub fn mul(a: Vec2, k: u32) Vec2 {
    return .{
        .x = a.x * k,
        .y = a.y * k,
    };
}

pub fn mulEq(self: *Vec2, k: u32) void {
    self.*.x *= k;
    self.*.y *= k;
}

pub fn divFloor(self: Vec2, denominator: u32) Vec2 {
    return .{
        .x = @divFloor(self.x, denominator),
        .y = @divFloor(self.y, denominator),
    };
}
