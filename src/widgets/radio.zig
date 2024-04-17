const std = @import("std");
const Widget = @import("Widget.zig");
const Vec2 = @import("../Vec2.zig");
const Rect = @import("../Rect.zig");
const events = @import("../events.zig");
const Frame = @import("../render/Frame.zig");
const Style = @import("../Style.zig");

pub const Config = struct {
    options: []const []const u8,

    selected: ?usize = null,
};

pub const Radio = @This();

const Marker = struct {
    const Selected: []const u8 = "[x] ";
    const Basic: []const u8 = "[ ] ";
};

allocator: std.mem.Allocator,

options: []const []const u8,

bounds: ?Vec2 = null,

selected: ?usize,

focused: ?usize = null,

pub fn create(allocator: std.mem.Allocator, config: Config) !*Radio {
    var options = try std.ArrayList([]const u8).initCapacity(allocator, config.options.len);
    for (config.options) |option| {
        try options.append(try allocator.dupe(u8, option));
    }

    const self = try allocator.create(Radio);
    self.* = Radio{
        .allocator = allocator,
        .options = try options.toOwnedSlice(),
        .selected = config.selected,
    };
    return self;
}

pub fn destroy(self: *Radio) void {
    for (self.options) |option| {
        self.allocator.free(option);
    }
    self.allocator.free(self.options);
    self.allocator.destroy(self);
}

pub fn widget(self: *Radio) Widget {
    return Widget.init(self);
}

pub fn render(self: *Radio, area: Rect, frame: *Frame) !void {
    const rows = @min(self.bounds.?.y, self.options.len);

    var row_area = Rect{
        .min = area.min,
        .max = .{ .x = area.max.x, .y = area.min.y + 1 },
    };

    for (self.options[0..rows], 0..) |option, idx| {
        if (idx == self.focused) frame.set_style(row_area, .{ .add_effect = .{ .highlight = true } });

        const marker = if (idx == self.selected) Marker.Selected else Marker.Basic;

        const to_write: [2][]const u8 = .{ marker, option };
        var len: usize = self.bounds.?.x;
        var cursor = row_area.min;
        for (to_write) |bytes| {
            if (len <= 0) break;
            const written = try frame.write_symbols(cursor, bytes, len);
            len -= written;
            cursor.x += @intCast(written);
        }

        row_area.min.y += 1;
        row_area.max.y += 1;
    }
}

pub fn desired_size(self: *Radio, _: Vec2) !Vec2 {
    const y = self.options.len;
    var x: usize = 0;
    for (self.options) |option| {
        x = @max(x, option.len + Marker.Basic.len);
    }
    return .{ .x = @intCast(x), .y = @intCast(y) };
}

pub fn layout(self: *Radio, bounds: Vec2) !void {
    self.bounds = bounds;
}

pub fn handle_event(self: *Radio, event: events.Event) !events.EventResult {
    switch (event) {
        .FocusIn => return .Consumed,
        .FocusOut => {
            self.focused = null;
            return .Consumed;
        },

        .Key, .ShiftKey => {
            if (self.focused) |focused| {
                const new_focused = if (event == .Key) focused + 1 else focused -% 1;
                if (new_focused < self.options.len) {
                    self.focused = new_focused;
                    return .Consumed;
                } else {
                    self.focused = null;
                    return .Ignored;
                }
            } else {
                if (event == .Key) {
                    self.focused = 0;
                } else {
                    self.focused = self.options.len - 1;
                }
                return .Consumed;
            }
        },

        .Char => |char| switch (char) {
            ' ' => {
                self.selected = self.focused;
                return .Consumed;
            },
            else => {},
        },
        else => {},
    }
    return .Ignored;
}
