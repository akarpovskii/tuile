const std = @import("std");
const internal = @import("../internal.zig");
const Backend = @import("Backend.zig");
const vec2 = @import("../vec2.zig");
const Vec2u = vec2.Vec2u;
const Vec2i = vec2.Vec2i;
const events = @import("../events.zig");
const display = @import("../display.zig");
const render = @import("../render.zig");

const Testing = @This();

frame_buffer: std.ArrayListUnmanaged(render.Cell),

window_size: Vec2u,

frame: render.Frame,

pub fn create(window_size: Vec2u) !*Testing {
    const self = try internal.allocator.create(Testing);
    var buffer = std.ArrayListUnmanaged(render.Cell){};
    try buffer.resize(internal.allocator, window_size.x * window_size.y);
    const window_area = .{
        .min = Vec2i.zero(),
        .max = window_size.as(i32),
    };
    const frame = render.Frame{
        .buffer = buffer.items,
        .total_area = window_area,
        .area = window_area,
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

pub fn printAt(self: *Testing, pos: Vec2u, text: []const u8) !void {
    self.frame.setSymbol(pos.as(i32), text);
}

pub fn windowSize(self: *Testing) !Vec2u {
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
