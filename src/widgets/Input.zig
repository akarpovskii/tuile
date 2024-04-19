const std = @import("std");
const Widget = @import("Widget.zig");
const Vec2 = @import("../Vec2.zig");
const Rect = @import("../Rect.zig");
const events = @import("../events.zig");
const Frame = @import("../render/Frame.zig");
const Color = @import("../color.zig").Color;
const FocusHandler = @import("FocusHandler.zig");
const Sized = @import("Sized.zig");
const Constraints = @import("Constraints.zig");

pub const Config = struct {
    placeholder: []const u8 = "",

    sized: Sized = .{},
};

const Input = @This();

allocator: std.mem.Allocator,

placeholder: []const u8,

value: std.ArrayList(u8),

focus_handler: FocusHandler = .{},

sized: Sized,

cursor: u32 = 0,

view_start: usize = 0,

pub fn create(allocator: std.mem.Allocator, config: Config) !*Input {
    const self = try allocator.create(Input);
    self.* = Input{
        .allocator = allocator,
        .placeholder = try allocator.dupe(u8, config.placeholder),
        .value = std.ArrayList(u8).init(allocator),
        .sized = config.sized,
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
    if (area.max.y - area.min.y < 1) {
        return;
    }
    frame.set_style(area, .{ .add_effect = .{ .underline = true } });

    const render_placeholder = self.value.items.len == 0;
    if (render_placeholder) frame.set_style(area, .{ .add_effect = .{ .dim = true } });

    const text_to_render = if (render_placeholder) self.placeholder else self.value.items;
    const visible = text_to_render[self.view_start..];
    _ = try frame.write_symbols(area.min, visible, area.max.x - area.min.x);

    if (self.focus_handler.focused) {
        var end_pos = area.min;
        end_pos.x += @intCast(self.cursor - self.view_start);
        if (end_pos.x >= area.max.x) {
            end_pos.x = area.max.x - 1;
        }
        const end_area = Rect{
            .min = end_pos,
            .max = end_pos.add(.{ .x = 1, .y = 1 }),
        };
        frame.set_style(end_area, .{ .fg = Color.dark_gray, .add_effect = .{ .reverse = true } });
    }
}

pub fn desired_size(self: *Input, _: Vec2) !Vec2 {
    const text_to_render = if (self.value.items.len > 0) self.value.items else self.placeholder;
    const len = try std.unicode.utf8CountCodepoints(text_to_render);

    // +1 for the cursor
    return .{ .x = @intCast(len + 1), .y = 1 };
}

pub fn layout(self: *Input, constraints: Constraints) !void {
    if (self.cursor < self.view_start) {
        self.view_start = self.cursor;
    } else {
        // +1 is for the cursor itself
        const visible = self.cursor - self.view_start + 1;
        if (visible > constraints.max_width) {
            self.view_start += visible - constraints.max_width;
        }
    }
}

pub fn handle_event(self: *Input, event: events.Event) !events.EventResult {
    if (self.focus_handler.handle_event(event) == .Consumed) {
        return .Consumed;
    }

    switch (event) {
        .Key, .ShiftKey => |key| switch (key) {
            .Left => {
                self.cursor -|= 1;
                return .Consumed;
            },
            .Right => {
                if (self.cursor < self.value.items.len) {
                    self.cursor += 1;
                }
                return .Consumed;
            },
            .Backspace => {
                if (self.cursor > 0) {
                    _ = self.value.orderedRemove(self.cursor - 1);
                }
                self.cursor -|= 1;
                return .Consumed;
            },
            .Delete => {
                if (self.cursor < self.value.items.len) {
                    _ = self.value.orderedRemove(self.cursor);
                }
                return .Consumed;
            },
            else => {},
        },

        .Char => |char| {
            try self.value.insert(self.cursor, char);
            self.cursor += 1;
            return .Consumed;
        },
        else => {},
    }
    return .Ignored;
}
