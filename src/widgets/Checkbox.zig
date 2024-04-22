const std = @import("std");
const internal = @import("../internal.zig");
const Widget = @import("Widget.zig");
const Vec2 = @import("../Vec2.zig");
const Rect = @import("../Rect.zig");
const events = @import("../events.zig");
const Frame = @import("../render/Frame.zig");
const FocusHandler = @import("FocusHandler.zig");
const LayoutProperties = @import("LayoutProperties.zig");
const Constraints = @import("Constraints.zig");
const display = @import("../display/display.zig");
const callbacks = @import("callbacks.zig");

pub const Config = struct {
    label: []const u8,

    checked: bool = false,

    on_state_change: ?callbacks.Callback(bool) = null,

    layout: LayoutProperties = .{},
};

pub const Checkbox = @This();

const Marker = struct {
    const Checked: []const u8 = "[*] ";
    const Basic: []const u8 = "[ ] ";
};

label: []const u8,

focus_handler: FocusHandler = .{},

layout_properties: LayoutProperties,

checked: bool,

on_state_change: ?callbacks.Callback(bool),

pub fn create(config: Config) !*Checkbox {
    const self = try internal.allocator.create(Checkbox);
    self.* = Checkbox{
        .label = try internal.allocator.dupe(u8, config.label),
        .checked = config.checked,
        .layout_properties = config.layout,
        .on_state_change = config.on_state_change,
    };
    return self;
}

pub fn destroy(self: *Checkbox) void {
    internal.allocator.free(self.label);
    internal.allocator.destroy(self);
}

pub fn widget(self: *Checkbox) Widget {
    return Widget.init(self);
}

pub fn render(self: *Checkbox, area: Rect, frame: Frame, theme: display.Theme) !void {
    if (area.height() < 1) {
        return;
    }
    self.focus_handler.render(area, frame, theme);

    const marker = if (self.checked) Marker.Checked else Marker.Basic;

    const to_write: [2][]const u8 = .{ marker, self.label };
    var len: usize = area.width();
    var cursor = area.min;
    for (to_write) |bytes| {
        if (len <= 0) break;
        const written = try frame.writeSymbols(cursor, bytes, len);
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

    const self_constraints = Constraints.fromProps(self.layout_properties);
    size = self_constraints.apply(size);
    size = constraints.apply(size);
    return size;
}

pub fn handleEvent(self: *Checkbox, event: events.Event) !events.EventResult {
    if (self.focus_handler.handleEvent(event) == .consumed) {
        return .consumed;
    }
    switch (event) {
        .char => |char| switch (char) {
            ' ' => {
                self.checked = !self.checked;
                if (self.on_state_change) |on_state_change| {
                    on_state_change.call(self.checked);
                }
                return .consumed;
            },
            else => {},
        },
        else => {},
    }
    return .ignored;
}

pub fn layoutProps(self: *Checkbox) LayoutProperties {
    return self.layout_properties;
}
