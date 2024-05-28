const std = @import("std");
const Cell = @import("Cell.zig");
const Vec2 = @import("../Vec2.zig");
const Rect = @import("../Rect.zig");
const Backend = @import("../backends/Backend.zig");
const display = @import("../display.zig");
const grapheme = @import("grapheme");
const DisplayWidth = @import("DisplayWidth");
const internal = @import("../internal.zig");

const Frame = @This();

/// Doesn't own the memory. Must be at least `size.x * size.y`.
buffer: []Cell,

/// The size of the buffer.
size: Vec2,

/// The area on which Frame is allowed to operate.
/// Any writes outside of the area are ignored.
area: Rect,

pub fn at(self: Frame, pos: Vec2) *Cell {
    return &self.buffer[pos.y * self.size.x + pos.x];
}

fn inside(self: Frame, pos: Vec2) bool {
    return self.area.min.x <= pos.x and pos.x < self.area.max.x and
        self.area.min.y <= pos.y and pos.y < self.area.max.y;
}

pub fn clear(self: Frame, fg: display.Color, bg: display.Color) void {
    for (self.buffer) |*cell| {
        cell.* = Cell{
            .fg = fg,
            .bg = bg,
        };
    }
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
    var iter = grapheme.Iterator.init(bytes, &internal.gd);
    const dw = DisplayWidth{ .data = &internal.dwd };

    var limit = max orelse std.math.maxInt(usize);
    var written: usize = 0;
    var cursor = start;
    while (iter.next()) |gc| {
        const substr = gc.bytes(bytes);
        const width = dw.strWidth(substr);
        if (width > limit) {
            break;
        }
        self.setSymbol(cursor, substr);

        cursor.x += @intCast(width);
        limit -= @intCast(width);
        written += @intCast(width);
    }
    return written;
}

pub fn render(self: Frame, backend: Backend) !void {
    const dw = DisplayWidth{ .data = &internal.dwd };
    for (0..self.size.y) |y| {
        // For the characters taking more than 1 column like の
        var overflow: usize = 0;
        for (0..self.size.x) |x| {
            const pos = Vec2{ .x = @intCast(x), .y = @intCast(y) };
            const cell = self.at(pos);
            try backend.enableEffect(cell.effect);
            try backend.useColor(.{ .fg = cell.fg, .bg = cell.bg });
            if (cell.symbol) |symbol| {
                try backend.printAt(pos, symbol);
                const width = dw.strWidth(symbol);
                overflow = width - 1;
            } else {
                if (overflow > 0) {
                    // Previous character occupies this column, do nothing
                    overflow -= 1;
                } else {
                    // Print whitespace to properly display the background
                    try backend.printAt(pos, " ");
                }
            }
            try backend.disableEffect(cell.effect);
        }
    }
    try backend.refresh();
}
