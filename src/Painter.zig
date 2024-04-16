const std = @import("std");
const Vec2 = @import("Vec2.zig");
const Backend = @import("backends/Backend.zig");
const Style = @import("Style.zig");

const Painter = @This();

cursor: Vec2,

backend: *Backend,

screen_size: Vec2,

pub fn init(backend: *Backend) !Painter {
    return .{
        .cursor = Vec2.zero(),
        .backend = backend,
        .screen_size = try backend.window_size(),
    };
}

pub fn print(self: *Painter, text: []const u8) !void {
    if (self.cursor.x < 0 or self.cursor.x >= self.screen_size.x or
        self.cursor.y < 0 or self.cursor.y >= self.screen_size.y)
    {
        return;
    }
    try self.backend.print_at(self.cursor, text);
    self.cursor.addEq(.{ .x = @intCast(text.len), .y = 0 });
}

pub fn print_at(self: *Painter, pos: Vec2, text: []const u8) !void {
    self.move_to(pos);
    try self.print(text);
}

pub fn print_border(self: *Painter, border: Style.Border, top_left: Vec2, bottom_right: Vec2) !void {
    // Corner points are printed twice: when printing edges, and when printing corners themselves.
    // This handles the case when top_left.x == bottom_right.x or top_left.y == bottom_right.y (e.g. Button).

    var x = top_left.x;
    while (x <= bottom_right.x) : (x += 1) {
        try self.print_at(.{ .x = x, .y = top_left.y }, border.top);
        try self.print_at(.{ .x = x, .y = bottom_right.y }, border.bottom);
    }

    var y = top_left.y;
    while (y <= bottom_right.y) : (y += 1) {
        try self.print_at(.{ .x = top_left.x, .y = y }, border.left);
        try self.print_at(.{ .x = bottom_right.x, .y = y }, border.right);
    }

    try self.print_at(.{ .x = top_left.x, .y = top_left.y }, border.top_left);
    try self.print_at(.{ .x = bottom_right.x, .y = top_left.y }, border.top_right);
    try self.print_at(.{ .x = top_left.x, .y = bottom_right.y }, border.bottom_left);
    try self.print_at(.{ .x = bottom_right.x, .y = bottom_right.y }, border.bottom_right);
}

pub fn offset(self: *Painter, value: Vec2) void {
    self.cursor.addEq(value);
}

pub fn move_to(self: *Painter, pos: Vec2) void {
    self.cursor = pos;
}
