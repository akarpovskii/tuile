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
    placeholder: []const u8 = "",

    on_value_changed: ?callbacks.Callback([]const u8) = null,

    layout: LayoutProperties = .{},
};

const Input = @This();

placeholder: []const u8,

on_value_changed: ?callbacks.Callback([]const u8),

value: std.ArrayList(u8),

focus_handler: FocusHandler = .{},

layout_properties: LayoutProperties,

cursor: u32 = 0,

view_start: usize = 0,

pub fn create(config: Config) !*Input {
    const self = try internal.allocator.create(Input);
    self.* = Input{
        .on_value_changed = config.on_value_changed,
        .placeholder = try internal.allocator.dupe(u8, config.placeholder),
        .value = std.ArrayList(u8).init(internal.allocator),
        .layout_properties = config.layout,
    };
    return self;
}

pub fn destroy(self: *Input) void {
    self.value.deinit();
    internal.allocator.free(self.placeholder);
    internal.allocator.destroy(self);
}

pub fn widget(self: *Input) Widget {
    return Widget.init(self);
}

pub fn render(self: *Input, area: Rect, frame: Frame, theme: display.Theme) !void {
    if (area.height() < 1) {
        return;
    }
    frame.setStyle(area, .{ .add_effect = .{ .underline = true } });

    const render_placeholder = self.value.items.len == 0;
    if (render_placeholder) frame.setStyle(area, .{ .add_effect = .{ .dim = true } });

    const text_to_render = self.currentText();
    const visible = text_to_render[self.view_start..];
    _ = try frame.writeSymbols(area.min, visible, area.width());

    if (self.focus_handler.focused) {
        var cursor_pos = area.min;
        cursor_pos.x += @intCast(self.cursor - self.view_start);
        if (cursor_pos.x >= area.max.x) {
            cursor_pos.x = area.max.x - 1;
        }
        const end_area = Rect{
            .min = cursor_pos,
            .max = cursor_pos.add(.{ .x = 1, .y = 1 }),
        };
        frame.setStyle(end_area, .{
            .fg = theme.cursor,
            .add_effect = .{ .reverse = true },
            .sub_effect = .{ .dim = true },
        });
    }
}

pub fn layout(self: *Input, constraints: Constraints) !Vec2 {
    if (self.cursor < self.view_start) {
        self.view_start = self.cursor;
    } else {
        // +1 is for the cursor itself
        const max_width = std.math.clamp(self.layout_properties.max_width, constraints.min_width, constraints.max_width);
        const visible = self.cursor - self.view_start + 1;
        if (visible > max_width) {
            self.view_start += visible - max_width;
        }
    }

    const visible = self.visibleText();
    // +1 for the cursor
    const len = try std.unicode.utf8CountCodepoints(visible) + 1;

    var size = Vec2{
        .x = @intCast(len),
        .y = 1,
    };

    const self_constraints = Constraints.fromProps(self.layout_properties);
    size = self_constraints.apply(size);
    size = constraints.apply(size);
    return size;
}

pub fn handleEvent(self: *Input, event: events.Event) !events.EventResult {
    if (self.focus_handler.handleEvent(event) == .consumed) {
        return .consumed;
    }

    switch (event) {
        .key, .shift_key => |key| switch (key) {
            .Left => {
                self.cursor -|= 1;
                return .consumed;
            },
            .Right => {
                if (self.cursor < self.value.items.len) {
                    self.cursor += 1;
                }
                return .consumed;
            },
            .Backspace => {
                if (self.cursor > 0) {
                    _ = self.value.orderedRemove(self.cursor - 1);
                    if (self.on_value_changed) |cb| cb.call(self.value.items);
                }
                self.cursor -|= 1;
                return .consumed;
            },
            .Delete => {
                if (self.cursor < self.value.items.len) {
                    _ = self.value.orderedRemove(self.cursor);
                    if (self.on_value_changed) |cb| cb.call(self.value.items);
                }
                return .consumed;
            },
            else => {},
        },

        .char => |char| {
            try self.value.insert(self.cursor, char);
            if (self.on_value_changed) |cb| cb.call(self.value.items);
            self.cursor += 1;
            return .consumed;
        },
        else => {},
    }
    return .ignored;
}

fn currentText(self: *Input) []const u8 {
    const show_placeholder = self.value.items.len == 0;
    return if (show_placeholder) self.placeholder else self.value.items;
}

fn visibleText(self: *Input) []const u8 {
    return self.currentText()[self.view_start..];
}

pub fn layoutProps(self: *Input) LayoutProperties {
    return self.layout_properties;
}
