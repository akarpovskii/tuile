const std = @import("std");
const Cell = @import("Cell.zig");
const vec2 = @import("../vec2.zig");
const Vec2u = vec2.Vec2u;
const Vec2i = vec2.Vec2i;
const Rect = @import("../rect.zig").Rect;
const Backend = @import("../backends/Backend.zig");
const display = @import("../display.zig");
const internal = @import("../internal.zig");
const text_clustering = @import("../text_clustering.zig");

const Frame = @This();

/// Doesn't own the memory. Must be at least `size.x * size.y`.
buffer: []Cell,

/// The size of the buffer.
total_area: Rect(i32),

/// The area on which Frame is allowed to operate.
/// Any writes outside of the area are ignored.
area: Rect(i32),

pub fn at(self: Frame, pos: Vec2i) *Cell {
    return &self.buffer[
        @intCast((pos.y - self.total_area.min.y) * self.total_area.width() +
            (pos.x - self.total_area.min.x))
    ];
}

fn inside(self: Frame, pos: Vec2i) bool {
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

pub fn withArea(self: Frame, area: Rect(i32)) Frame {
    return Frame{
        .buffer = self.buffer,
        .total_area = self.total_area,
        .area = self.area.intersect(area),
    };
}

pub fn setStyle(self: Frame, area: Rect(i32), style: display.Style) void {
    for (0..@intCast(area.height())) |dy| {
        for (0..@intCast(area.width())) |dx| {
            const pos = Vec2i{
                .x = area.min.x + @as(i32, @intCast(dx)),
                .y = area.min.y + @as(i32, @intCast(dy)),
            };
            if (self.inside(pos)) {
                self.at(pos).setStyle(style);
            }
        }
    }
}

pub fn setSymbol(self: Frame, pos: Vec2i, symbol: []const u8) void {
    if (self.inside(pos)) {
        self.at(pos).symbol = symbol;
    }
}

// Decodes text as UTF-8, writes all code points separately and returns the number of 'characters' written
pub fn writeSymbols(self: Frame, start: Vec2i, bytes: []const u8, max: ?usize) !usize {
    var iter = try text_clustering.ClusterIterator.init(internal.text_clustering_type, bytes);
    var limit = max orelse std.math.maxInt(usize);
    var written: usize = 0;
    var cursor = start;
    while (iter.next()) |cluster| {
        if (cluster.display_width > limit) {
            break;
        }
        self.setSymbol(cursor, cluster.bytes(bytes));

        cursor.x += @intCast(cluster.display_width);
        limit -= @intCast(cluster.display_width);
        written += @intCast(cluster.display_width);
    }
    return written;
}

pub fn render(self: Frame, backend: Backend) !void {
    var last_effect = display.Style.Effect{};
    var last_color: ?display.ColorPair = null;

    try backend.disableEffect(display.Style.Effect.all());

    for (0..@intCast(self.area.height())) |dy| {
        // for (0..self.size.y) |y| {
        // For the characters taking more than 1 column like の
        var overflow: usize = 0;
        // for (0..self.size.x) |x| {
        for (0..@intCast(self.area.width())) |dx| {
            const pos = Vec2i{
                .x = self.area.min.x + @as(i32, @intCast(dx)),
                .y = self.area.min.y + @as(i32, @intCast(dy)),
            };
            if (pos.x < 0 or pos.y < 0) {
                continue;
            }
            const cell = self.at(pos);
            const none = display.Style.Effect{};

            // Effects that are true in last, but false in cell
            const disable = last_effect.sub(cell.effect);
            if (!std.meta.eql(disable, none)) {
                try backend.disableEffect(disable);
            }

            // Effects that are true in cell, but false in last
            const enable = cell.effect.sub(last_effect);
            if (!std.meta.eql(enable, none)) {
                try backend.enableEffect(enable);
            }
            last_effect = cell.effect;

            if (last_color) |lcolor| {
                if (!std.meta.eql(lcolor.fg, cell.fg) or !std.meta.eql(lcolor.bg, cell.bg)) {
                    try backend.useColor(.{ .fg = cell.fg, .bg = cell.bg });
                }
            } else {
                try backend.useColor(.{ .fg = cell.fg, .bg = cell.bg });
            }
            last_color = .{ .fg = cell.fg, .bg = cell.bg };

            if (cell.symbol) |symbol| {
                try backend.printAt(pos.as(u32), symbol);
                const width = try text_clustering.stringDisplayWidth(symbol, internal.text_clustering_type);
                overflow = width -| 1;
            } else {
                if (overflow > 0) {
                    // Previous character occupies this column, do nothing
                    overflow -= 1;
                } else {
                    // Print whitespace to properly display the background
                    try backend.printAt(pos.as(u32), " ");
                }
            }
        }
    }
    try backend.refresh();
}
