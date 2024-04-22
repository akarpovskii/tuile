const std = @import("std");
const internal = @import("../internal.zig");
const Widget = @import("Widget.zig");
const Vec2 = @import("../Vec2.zig");
const Rect = @import("../Rect.zig");
const events = @import("../events.zig");
const Frame = @import("../render/Frame.zig");
const LayoutProperties = @import("LayoutProperties.zig");
const Constraints = @import("Constraints.zig");
const Theme = @import("../Theme.zig");

pub const Config = struct {
    text: []const u8,

    layout: LayoutProperties = .{},
};

pub const Label = @This();

text: []const u8,

lines: [][]const u8,

layout_properties: LayoutProperties,

pub fn create(config: Config) !*Label {
    const text = try internal.allocator.dupe(u8, config.text);
    var lines = std.ArrayList([]const u8).init(internal.allocator);
    defer lines.deinit();

    var iter = std.mem.tokenizeScalar(u8, text, '\n');
    while (iter.next()) |line| {
        try lines.append(line);
    }

    const self = try internal.allocator.create(Label);
    self.* = Label{
        .text = text,
        .lines = try lines.toOwnedSlice(),
        .layout_properties = config.layout,
    };
    return self;
}

pub fn destroy(self: *Label) void {
    internal.allocator.free(self.lines);
    internal.allocator.free(self.text);
    internal.allocator.destroy(self);
}

pub fn widget(self: *Label) Widget {
    return Widget.init(self);
}

pub fn render(self: *Label, area: Rect, frame: Frame, _: Theme) !void {
    for (0..area.height()) |y| {
        if (y >= self.lines.len) break;
        const pos = area.min.add(.{ .x = 0, .y = @intCast(y) });
        _ = try frame.writeSymbols(pos, self.lines[y], area.width());
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

    const self_constraints = Constraints.fromProps(self.layout_properties);
    size = self_constraints.apply(size);
    size = constraints.apply(size);
    return size;
}

pub fn handleEvent(_: *Label, _: events.Event) !events.EventResult {
    return .ignored;
}

pub fn layoutProps(self: *Label) LayoutProperties {
    return self.layout_properties;
}
