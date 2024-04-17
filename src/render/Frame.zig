const std = @import("std");
const Cell = @import("Cell.zig");
const Vec2 = @import("../Vec2.zig");
const Rect = @import("../Rect.zig");
const Color = @import("../color.zig").Color;
const Style = @import("../Style.zig");

const Frame = @This();

allocator: std.mem.Allocator,

buffer: []Cell,

size: Vec2,

pub fn init(allocator: std.mem.Allocator, size: Vec2) !Frame {
    const buffer = try allocator.alloc(Cell, size.x * size.y);
    for (buffer) |*cell| {
        cell.* = .{};
    }
    return .{
        .allocator = allocator,
        .buffer = buffer,
        .size = size,
    };
}

pub fn deinit(self: *Frame) void {
    self.allocator.free(self.buffer);
}

pub fn at(self: *Frame, pos: Vec2) *Cell {
    return &self.buffer[pos.y * self.size.x + pos.x];
}

pub fn set_style(self: *Frame, area: Rect, style: Style) void {
    for (area.min.y..area.max.y) |y| {
        for (area.min.x..area.max.x) |x| {
            self.at(.{ .x = @intCast(x), .y = @intCast(y) }).set_style(style);
        }
    }
}

// Decodes text as UTF-8, writes all code points separately and returns the number of 'characters' written
// TODO: Use graphemes instead of code points!
pub fn write_symbols(self: *Frame, start: Vec2, bytes: []const u8, max: ?usize) !usize {
    const utf8_view = try std.unicode.Utf8View.init(bytes);
    var iter = utf8_view.iterator();
    var limit = max orelse std.math.maxInt(usize);
    var written: usize = 0;
    var cursor = start;
    while (iter.nextCodepointSlice()) |cp| {
        if (limit == 0) {
            break;
        }
        self.at(cursor).symbol = cp;
        cursor.x += 1;
        limit -= 1;
        written += 1;
    }
    return written;
}
