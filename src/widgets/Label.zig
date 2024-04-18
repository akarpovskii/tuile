const std = @import("std");
const Widget = @import("Widget.zig");
const Vec2 = @import("../Vec2.zig");
const Rect = @import("../Rect.zig");
const events = @import("../events.zig");
const Frame = @import("../render/Frame.zig");

pub const Config = struct {
    text: []const u8,
};

pub const Label = @This();

allocator: std.mem.Allocator,

text: []const u8,

lines: [][]const u8,

pub fn create(allocator: std.mem.Allocator, config: Config) !*Label {
    const text = try allocator.dupe(u8, config.text);
    var lines = std.ArrayList([]const u8).init(allocator);
    defer lines.deinit();

    var iter = std.mem.tokenizeScalar(u8, text, '\n');
    while (iter.next()) |line| {
        try lines.append(line);
    }

    const self = try allocator.create(Label);
    self.* = Label{
        .allocator = allocator,
        .text = text,
        .lines = try lines.toOwnedSlice(),
    };
    return self;
}

pub fn destroy(self: *Label) void {
    self.allocator.free(self.lines);
    self.allocator.free(self.text);
    self.allocator.destroy(self);
}

pub fn widget(self: *Label) Widget {
    return Widget.init(self);
}

pub fn render(self: *Label, area: Rect, frame: *Frame) !void {
    for (0..area.max.y - area.min.y) |y| {
        if (y >= self.lines.len) break;
        const pos = area.min.add(.{ .x = 0, .y = @intCast(y) });
        _ = try frame.write_symbols(pos, self.lines[y], area.max.x - area.min.x);
    }
}

pub fn desired_size(self: *Label, _: Vec2) !Vec2 {
    var x: usize = 0;
    for (self.lines) |line| {
        const len: usize = try std.unicode.utf8CountCodepoints(line);
        x = @max(x, len);
    }
    return .{ .x = @intCast(x), .y = @intCast(self.lines.len) };
}

pub fn layout(_: *Label, _: Vec2) !void {}

pub fn handle_event(_: *Label, _: events.Event) !events.EventResult {
    return .Ignored;
}
