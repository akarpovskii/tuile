const std = @import("std");
const Widget = @import("Widget.zig");
const Vec2 = @import("../Vec2.zig");
const Rect = @import("../Rect.zig");
const events = @import("../events.zig");
const Frame = @import("../render/Frame.zig");
const Color = @import("../color.zig").Color;

pub const Config = struct {
    placeholder: []const u8 = "",
};

const Input = @This();

allocator: std.mem.Allocator,

placeholder: []const u8,

value: std.ArrayList(u8),

focused: bool = false,

pub fn create(allocator: std.mem.Allocator, config: Config) !*Input {
    const self = try allocator.create(Input);
    self.* = Input{
        .allocator = allocator,
        .placeholder = try allocator.dupe(u8, config.placeholder),
        .value = std.ArrayList(u8).init(allocator),
    };
    return self;
}

pub fn destroy(self: *Input) void {
    self.allocator.free(self.placeholder);
    self.value.deinit();
    self.allocator.destroy(self);
}

pub fn widget(self: *Input) Widget {
    return Widget.init(self);
}

pub fn render(self: *Input, area: Rect, frame: *Frame) !void {
    const render_placeholder = self.value.items.len == 0;
    if (render_placeholder) frame.set_style(area, .{ .add_effect = .{ .dim = true } });

    const text_to_render = if (render_placeholder) self.placeholder else self.value.items;

    const written = try frame.write_symbols(area.min, text_to_render, area.max.x - area.min.x);
    if (self.focused) {
        if (render_placeholder) {
            frame.set_style(area, .{ .add_effect = .{ .highlight = true } });
        } else {
            const end_pos = area.min.add(.{ .x = @intCast(written), .y = 0 });
            const end_area = Rect{
                .min = end_pos,
                .max = end_pos.add(.{ .x = 1, .y = 1 }),
            };
            frame.set_style(end_area, .{ .fg = Color.dark_gray, .add_effect = .{ .blink = true } });
            _ = try frame.write_symbols(end_pos, "█", area.max.x - area.min.x);
        }
    }
}

pub fn desired_size(self: *Input, _: Vec2) !Vec2 {
    const text_to_render = if (self.value.items.len > 0) self.value.items else self.placeholder;

    return .{ .x = @intCast(try std.unicode.utf8CountCodepoints(text_to_render)), .y = 1 };
}

pub fn layout(_: *Input, _: Vec2) !void {}

pub fn handle_event(self: *Input, event: events.Event) !events.EventResult {
    switch (event) {
        .FocusIn => return .Consumed,
        .FocusOut => {
            self.focused = false;
            return .Consumed;
        },

        .Key, .ShiftKey => |key| switch (key) {
            .Tab => {
                if (!self.focused) {
                    self.focused = true;
                    return .Consumed;
                } else {
                    return .Ignored;
                }
            },
            .Backspace => {
                _ = self.value.popOrNull();
                return .Consumed;
            },
            else => {},
        },

        .Char => |char| {
            try self.value.append(char);
            return .Consumed;
        },
        else => {},
    }
    return .Ignored;
}