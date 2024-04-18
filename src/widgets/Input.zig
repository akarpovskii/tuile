const std = @import("std");
const Widget = @import("Widget.zig");
const Vec2 = @import("../Vec2.zig");
const Rect = @import("../Rect.zig");
const events = @import("../events.zig");
const Frame = @import("../render/Frame.zig");
const Color = @import("../color.zig").Color;
const FocusHandler = @import("FocusHandler.zig");

pub const Config = struct {
    placeholder: []const u8 = "",
};

const Input = @This();

allocator: std.mem.Allocator,

placeholder: []const u8,

value: std.ArrayList(u8),

focus_handler: FocusHandler = .{},

cursor: Vec2 = Vec2.zero(),

cursor_idx: usize = 0,

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

    // TODO: Handle Unicode input
    _ = try frame.write_symbols(area.min, text_to_render, area.max.x - area.min.x);
    if (self.focus_handler.focused) {
        if (render_placeholder) {
            self.focus_handler.render(area, frame);
        } else {
            const end_pos = area.min.add(self.cursor);
            const end_area = Rect{
                .min = end_pos,
                .max = end_pos.add(.{ .x = 1, .y = 1 }),
            };
            frame.set_style(end_area, .{ .fg = Color.dark_gray, .add_effect = .{ .reverse = true } });
            // _ = try frame.write_symbols(end_pos, "█", area.max.x - area.min.x);
        }
    }
}

pub fn desired_size(self: *Input, _: Vec2) !Vec2 {
    const text_to_render = if (self.value.items.len > 0) self.value.items else self.placeholder;

    return .{ .x = @intCast(try std.unicode.utf8CountCodepoints(text_to_render)), .y = 1 };
}

pub fn layout(_: *Input, _: Vec2) !void {}

pub fn handle_event(self: *Input, event: events.Event) !events.EventResult {
    if (self.focus_handler.handle_event(event) == .Consumed) {
        return .Consumed;
    }

    switch (event) {
        .Key, .ShiftKey => |key| switch (key) {
            .Left => {
                self.cursor.x -|= 1;
                self.cursor_idx -|= 1;
                return .Consumed;
            },
            .Right => {
                if (self.cursor_idx < self.value.items.len) {
                    self.cursor.x += 1;
                    self.cursor_idx += 1;
                }
                return .Consumed;
            },
            .Backspace => {
                if (self.cursor_idx > 0) {
                    _ = self.value.orderedRemove(self.cursor_idx - 1);
                }
                self.cursor.x -|= 1;
                self.cursor_idx -|= 1;
                return .Consumed;
            },
            .Delete => {
                if (self.cursor_idx < self.value.items.len) {
                    _ = self.value.orderedRemove(self.cursor_idx);
                }
                return .Consumed;
            },
            else => {},
        },

        .Char => |char| {
            try self.value.insert(self.cursor_idx, char);
            self.cursor.x += 1;
            self.cursor_idx += 1;
            return .Consumed;
        },
        else => {},
    }
    return .Ignored;
}
