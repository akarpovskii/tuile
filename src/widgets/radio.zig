const std = @import("std");
const Widget = @import("Widget.zig");
const Vec2 = @import("../Vec2.zig");
const events = @import("../events.zig");
const Painter = @import("../Painter.zig");

pub const Config = struct {
    options: []const []const u8,

    selected: ?usize = null,
};

pub const Radio = @This();

const Marker = struct {
    const Selected = "[x] ";
    const Basic = "[ ] ";
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

pub fn draw(self: *Radio, painter: *Painter) !void {
    const rows = if (self.bounds) |bounds| bounds.y else self.options.len;
    var cursor = painter.cursor;

    for (self.options[0..rows], 0..) |option, idx| {
        if (idx == self.focused) try painter.backend.enable_effect(.highlight);

        painter.move_to(cursor);

        const marker = if (idx == self.selected) Marker.Selected else Marker.Basic;
        const desired_len = marker.len + option.len;

        const len = if (self.bounds) |bounds|
            @min(bounds.x, desired_len)
        else
            desired_len;

        if (len <= marker.len) {
            // Only marker is visible
            try painter.print(marker[0..len]);
        } else {
            try painter.print(marker);
            try painter.print(option[0..@min(option.len, len - marker.len)]);
        }

        if (idx == self.focused) try painter.backend.disable_effect(.highlight);

        cursor.y += 1;
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
