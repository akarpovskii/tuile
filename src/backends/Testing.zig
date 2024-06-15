const std = @import("std");
const internal = @import("../internal.zig");
const Backend = @import("Backend.zig");
const Vec2 = @import("../Vec2.zig");
const events = @import("../events.zig");
const display = @import("../display.zig");
const render = @import("../render.zig");

const Testing = @This();

frame_buffer: std.ArrayListUnmanaged(render.Cell),

window_size: Vec2,

frame: render.Frame,

pub fn create(window_size: Vec2) !*Testing {
    const self = try internal.allocator.create(Testing);
    var buffer = std.ArrayListUnmanaged(render.Cell){};
    try buffer.resize(internal.allocator, window_size.x * window_size.y);
    const frame = render.Frame{
        .size = window_size,
        .buffer = buffer.items,
        .area = .{
            .min = Vec2.zero(),
            .max = window_size,
        },
        .grapheme_clustering = false,
    };
    frame.clear(display.color("black"), display.color("white"));

    self.* = .{
        .window_size = window_size,
        .frame_buffer = buffer,
        .frame = frame,
    };
    return self;
}

pub fn destroy(self: *Testing) void {
    self.frame_buffer.deinit(internal.allocator);
    internal.allocator.destroy(self);
}

pub fn backend(self: *Testing) Backend {
    return Backend.init(self);
}

pub fn pollEvent(_: *Testing) !?events.Event {
    return null;
}

pub fn refresh(_: *Testing) !void {}

pub fn printAt(self: *Testing, pos: Vec2, text: []const u8) !void {
    self.frame.setSymbol(pos, text);
}

pub fn windowSize(self: *Testing) !Vec2 {
    return self.window_size;
}

pub fn enableEffect(_: *Testing, _: display.Style.Effect) !void {}

pub fn disableEffect(_: *Testing, _: display.Style.Effect) !void {}

pub fn useColor(_: *Testing, _: display.ColorPair) !void {}

pub fn write(self: *Testing, writer: anytype) !void {
    for (0..self.window_size.y) |y| {
        for (0..self.window_size.x) |x| {
            const cell = self.frame.at(.{
                .x = @intCast(x),
                .y = @intCast(y),
            });
            if (cell.symbol) |symbol| {
                try writer.writeAll(symbol);
            } else {
                try writer.writeByte(' ');
            }
        }
        try writer.writeByte('\n');
    }
}

pub fn requestMode(_: *Testing, _: u32) !Backend.ReportMode {
    return .not_recognized;
}
