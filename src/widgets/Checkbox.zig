const std = @import("std");
const Widget = @import("Widget.zig");
const Vec2 = @import("../Vec2.zig");
const Rect = @import("../Rect.zig");
const events = @import("../events.zig");
const Frame = @import("../render/Frame.zig");
const Label = @import("Label.zig").Label;
const Style = @import("../Style.zig");
const FocusHandler = @import("FocusHandler.zig");
const Sized = @import("Sized.zig");
const Constraints = @import("Constraints.zig");

pub const Config = struct {
    label: []const u8,

    checked: bool = false,

    sized: Sized = .{},
};

pub const Checkbox = @This();

const Marker = struct {
    const Checked: []const u8 = "[*] ";
    const Basic: []const u8 = "[ ] ";
};

allocator: std.mem.Allocator,

label: []const u8,

focus_handler: FocusHandler = .{},

sized: Sized,

checked: bool,

pub fn create(allocator: std.mem.Allocator, config: Config) !*Checkbox {
    const self = try allocator.create(Checkbox);
    self.* = Checkbox{
        .allocator = allocator,
        .label = try allocator.dupe(u8, config.label),
        .checked = config.checked,
        .sized = config.sized,
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

pub fn render(self: *Checkbox, area: Rect, frame: Frame) !void {
    if (area.max.y - area.min.y < 1) {
        return;
    }
    self.focus_handler.render(area, frame);

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

pub fn layout(self: *Checkbox, constraints: Constraints) !Vec2 {
    const len: u32 = @intCast(try std.unicode.utf8CountCodepoints(self.label) + Marker.Basic.len);
    var size = Vec2{
        .x = len,
        .y = 1,
    };

    const self_constraints = Constraints.from_sized(self.sized);
    size = self_constraints.apply(size);
    size = constraints.apply(size);
    return size;
}

pub fn handle_event(self: *Checkbox, event: events.Event) !events.EventResult {
    if (self.focus_handler.handle_event(event) == .Consumed) {
        return .Consumed;
    }
    switch (event) {
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
