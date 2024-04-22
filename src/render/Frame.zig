const std = @import("std");
const Cell = @import("Cell.zig");
const Vec2 = @import("../Vec2.zig");
const Rect = @import("../Rect.zig");
const Backend = @import("../backends/Backend.zig");
const display = @import("../display/display.zig");

const Frame = @This();

buffer: []Cell,

size: Vec2,

area: Rect,

fn at(self: Frame, pos: Vec2) *Cell {
    return &self.buffer[pos.y * self.size.x + pos.x];
}

fn inside(self: Frame, pos: Vec2) bool {
    return self.area.min.x <= pos.x and pos.x < self.area.max.x and
        self.area.min.y <= pos.y and pos.y < self.area.max.y;
}

pub fn withArea(self: Frame, area: Rect) Frame {
    return Frame{
        .buffer = self.buffer,
        .size = self.size,
        .area = self.area.intersect(area),
    };
}

pub fn setStyle(self: Frame, area: Rect, style: display.Style) void {
    for (area.min.y..area.max.y) |y| {
        for (area.min.x..area.max.x) |x| {
            const pos = Vec2{ .x = @intCast(x), .y = @intCast(y) };
            if (self.inside(pos)) {
                self.at(pos).setStyle(style);
            }
        }
    }
}

pub fn setSymbol(self: Frame, pos: Vec2, symbol: []const u8) void {
    if (self.inside(pos)) {
        self.at(pos).symbol = symbol;
    }
}

// Decodes text as UTF-8, writes all code points separately and returns the number of 'characters' written
// TODO: Use graphemes instead of code points!
pub fn writeSymbols(self: Frame, start: Vec2, bytes: []const u8, max: ?usize) !usize {
    const utf8_view = try std.unicode.Utf8View.init(bytes);
    var iter = utf8_view.iterator();
    var limit = max orelse std.math.maxInt(usize);
    var written: usize = 0;
    var cursor = start;
    while (iter.nextCodepointSlice()) |cp| {
        if (limit == 0) {
            break;
        }
        self.setSymbol(cursor, cp);
        cursor.x += 1;
        limit -= 1;
        written += 1;
    }
    return written;
}

pub fn render(self: Frame, backend: Backend) !void {
    for (0..self.size.x) |x| {
        for (0..self.size.y) |y| {
            const pos = Vec2{ .x = @intCast(x), .y = @intCast(y) };
            const cell = self.at(pos);
            try backend.enableEffect(cell.effect);
            try backend.useColor(.{ .fg = cell.fg, .bg = cell.bg });
            if (cell.symbol) |symbol| {
                try backend.printAt(pos, symbol);
            } else {
                try backend.printAt(pos, " ");
            }
            try backend.disableEffect(cell.effect);
        }
    }
    try backend.refresh();
}
