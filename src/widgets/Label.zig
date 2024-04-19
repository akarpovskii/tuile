const std = @import("std");
const Widget = @import("Widget.zig");
const Vec2 = @import("../Vec2.zig");
const Rect = @import("../Rect.zig");
const events = @import("../events.zig");
const Frame = @import("../render/Frame.zig");
const LayoutProperties = @import("LayoutProperties.zig");
const Constraints = @import("Constraints.zig");

pub const Config = struct {
    text: []const u8,

    layout: LayoutProperties = .{},
};

pub const Label = @This();

allocator: std.mem.Allocator,

text: []const u8,

lines: [][]const u8,

layout_properties: LayoutProperties,

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
        .layout_properties = config.layout,
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

pub fn render(self: *Label, area: Rect, frame: Frame) !void {
    for (0..area.height()) |y| {
        if (y >= self.lines.len) break;
        const pos = area.min.add(.{ .x = 0, .y = @intCast(y) });
        _ = try frame.write_symbols(pos, self.lines[y], area.width());
    }
}

pub fn layout(self: *Label, constraints: Constraints) !Vec2 {
    var max_len: usize = 0;
    for (self.lines) |line| {
        const len: usize = try std.unicode.utf8CountCodepoints(line);
        max_len = @max(max_len, len);
    }

    var size = Vec2{
        .x = @intCast(max_len),
        .y = @intCast(self.lines.len),
    };

    const self_constraints = Constraints.from_props(self.layout_properties);
    size = self_constraints.apply(size);
    size = constraints.apply(size);
    return size;
}

pub fn handle_event(_: *Label, _: events.Event) !events.EventResult {
    return .Ignored;
}

pub fn layout_props(self: *Label) LayoutProperties {
    return self.layout_properties;
}
