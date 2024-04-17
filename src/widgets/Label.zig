const std = @import("std");
const Widget = @import("Widget.zig");
const Vec2 = @import("../Vec2.zig");
const Rect = @import("../Rect.zig");
const events = @import("../events.zig");
const Frame = @import("../render/Frame.zig");

pub const Config = struct {
    text: []const u8,

    wrap: bool = false,
};

pub const Label = @This();

allocator: std.mem.Allocator,

text: []const u8,

wrap: bool,

bounds: ?Vec2 = null,

pub fn create(allocator: std.mem.Allocator, config: Config) !*Label {
    const self = try allocator.create(Label);
    self.* = Label{
        .allocator = allocator,
        .text = try allocator.dupe(u8, config.text),
        .wrap = config.wrap,
    };
    return self;
}

pub fn destroy(self: *Label) void {
    self.allocator.free(self.text);
    self.allocator.destroy(self);
}

pub fn widget(self: *Label) Widget {
    return Widget.init(self);
}

pub fn render(self: *Label, area: Rect, frame: *Frame) !void {
    _ = try frame.write_symbols(area.min, self.text, self.bounds.?.x);
}

pub fn desired_size(self: *Label, _: Vec2) !Vec2 {
    return .{ .x = @intCast(self.text.len), .y = 1 };
}

pub fn layout(self: *Label, bounds: Vec2) !void {
    self.bounds = .{
        .x = @min(self.text.len, bounds.x),
        .y = @min(1, bounds.y),
    };
}

pub fn handle_event(_: *Label, _: events.Event) !events.EventResult {
    return .Ignored;
}
