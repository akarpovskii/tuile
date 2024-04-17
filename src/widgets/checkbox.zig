const std = @import("std");
const Widget = @import("Widget.zig");
const Vec2 = @import("../Vec2.zig");
const Rect = @import("../Rect.zig");
const events = @import("../events.zig");
const Frame = @import("../render/Frame.zig");
const Label = @import("Label.zig").Label;
const Style = @import("../Style.zig");

pub const Config = struct {
    label: []const u8,

    checked: bool = false,
};

pub const Checkbox = @This();

const Marker = struct {
    const Checked: []const u8 = "[*] ";
    const Basic: []const u8 = "[ ] ";
};

allocator: std.mem.Allocator,

label: []const u8,

focused: bool = false,

checked: bool,

pub fn create(allocator: std.mem.Allocator, config: Config) !*Checkbox {
    const self = try allocator.create(Checkbox);
    self.* = Checkbox{
        .allocator = allocator,
        .label = try allocator.dupe(u8, config.label),
        .checked = config.checked,
    };
    return self;
}

pub fn destroy(self: *Checkbox) void {
    self.allocator.free(self.label);
    self.allocator.destroy(self);
}

pub fn widget(self: *Checkbox) Widget {
    return Widget.init(self);
}

pub fn render(self: *Checkbox, area: Rect, frame: *Frame) !void {
    if (self.focused) frame.set_style(area, .{ .add_effect = .{ .highlight = true } });

    const marker = if (self.checked) Marker.Checked else Marker.Basic;

    const to_write: [2][]const u8 = .{ marker, self.label };
    var len: usize = area.max.x - area.min.x;
    var cursor = area.min;
    for (to_write) |bytes| {
        if (len <= 0) break;
        const written = try frame.write_symbols(cursor, bytes, len);
        len -= written;
        cursor.x += @intCast(written);
    }
}

pub fn desired_size(self: *Checkbox, _: Vec2) !Vec2 {
    const x = try std.unicode.utf8CountCodepoints(self.label) + Marker.Basic.len;
    return .{ .x = @intCast(x), .y = 1 };
}

pub fn layout(self: *Checkbox, bounds: Vec2) !void {
    _ = self;
    _ = bounds;
}

pub fn handle_event(self: *Checkbox, event: events.Event) !events.EventResult {
    switch (event) {
        .FocusIn => return .Consumed,
        .FocusOut => {
            self.focused = false;
            return .Consumed;
        },

        .Key, .ShiftKey => {
            if (!self.focused) {
                self.focused = true;
                return .Consumed;
            } else {
                return .Ignored;
            }
        },

        .Char => |char| switch (char) {
            ' ' => {
                self.checked = !self.checked;
                return .Consumed;
            },
            else => {},
        },
        else => {},
    }
    return .Ignored;
}
