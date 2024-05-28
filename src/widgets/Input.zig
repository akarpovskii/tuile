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
const display = @import("../display.zig");
const callbacks = @import("callbacks.zig");
const DisplayWidth = @import("DisplayWidth");
const grapheme = @import("grapheme");

pub const Config = struct {
    /// A unique identifier of the widget to be used in `Tuile.findById` and `Widget.findById`.
    id: ?[]const u8 = null,

    /// Text to be used as a placeholder when the input is empty.
    placeholder: []const u8 = "",

    /// Input will call this when its value changes.
    on_value_changed: ?callbacks.Callback([]const u8) = null,

    /// Layout properties of the widget, see `LayoutProperties`.
    layout: LayoutProperties = .{},
};

const Input = @This();

pub usingnamespace Widget.Leaf.Mixin(Input);
pub usingnamespace Widget.Base.Mixin(Input, .widget_base);

widget_base: Widget.Base,

placeholder: []const u8,

on_value_changed: ?callbacks.Callback([]const u8),

value: std.ArrayListUnmanaged(u8),

focus_handler: FocusHandler = .{},

layout_properties: LayoutProperties,

cursor: u32 = 0,

view_start: usize = 0,

pub fn create(config: Config) !*Input {
    const self = try internal.allocator.create(Input);
    self.* = Input{
        .widget_base = try Widget.Base.init(config.id),
        .on_value_changed = config.on_value_changed,
        .placeholder = try internal.allocator.dupe(u8, config.placeholder),
        .value = std.ArrayListUnmanaged(u8){},
        .layout_properties = config.layout,
    };
    return self;
}

pub fn destroy(self: *Input) void {
    self.widget_base.deinit();
    self.value.deinit(internal.allocator);
    internal.allocator.free(self.placeholder);
    internal.allocator.destroy(self);
}

pub fn widget(self: *Input) Widget {
    return Widget.init(self);
}

pub fn setPlaceholder(self: *Input, text: []const u8) !void {
    internal.allocator.free(self.placeholder);
    self.placeholder = try internal.allocator.dupe(u8, text);
}

pub fn setValue(self: *Input, value: []const u8) !void {
    self.value.deinit(internal.allocator);
    self.value = std.ArrayListUnmanaged(u8){};
    try self.value.appendSlice(internal.allocator, value);
    self.cursor = value.len;
}

pub fn render(self: *Input, area: Rect, frame: Frame, theme: display.Theme) !void {
    if (area.height() < 1) {
        return;
    }
    frame.setStyle(area, .{ .bg = theme.interactive, .add_effect = .{ .underline = true } });
    self.focus_handler.render(area, frame, theme);

    const render_placeholder = self.value.items.len == 0;
    if (render_placeholder) frame.setStyle(area, .{ .fg = theme.text_secondary });

    const text_to_render = self.currentText();
    const visible = text_to_render[self.view_start..];
    _ = try frame.writeSymbols(area.min, visible, area.width());

    if (self.focus_handler.focused) {
        const dw = DisplayWidth{ .data = &internal.dwd };

        var cursor_pos = area.min;
        cursor_pos.x += @intCast(dw.strWidth(text_to_render[self.view_start..self.cursor]));
        if (cursor_pos.x >= area.max.x) {
            cursor_pos.x = area.max.x - 1;
        }
        const end_area = Rect{
            .min = cursor_pos,
            .max = cursor_pos.add(.{ .x = 1, .y = 1 }),
        };
        frame.setStyle(end_area, .{
            .bg = theme.solid,
        });
    }
}

pub fn layout(self: *Input, constraints: Constraints) !Vec2 {
    const dw = DisplayWidth{ .data = &internal.dwd };
    if (self.cursor < self.view_start) {
        self.view_start = self.cursor;
    } else {
        const max_width = std.math.clamp(self.layout_properties.max_width, constraints.min_width, constraints.max_width);
        // +1 is for the cursor itself
        const visible_text = self.currentText()[self.view_start..self.cursor];
        var visible = dw.strWidth(visible_text) + 1;
        if (visible > max_width) {
            var iter = grapheme.Iterator.init(visible_text, &internal.gd);
            while (iter.next()) |gc| {
                self.view_start += gc.len;
                visible -= 1;
                if (visible <= max_width) {
                    break;
                }
            }
        }
    }

    const visible = self.visibleText();
    // +1 for the cursor
    const len = dw.strWidth(visible) + 1;

    var size = Vec2{
        .x = @intCast(len),
        .y = 1,
    };

    const self_constraints = Constraints.fromProps(self.layout_properties);
    size = self_constraints.apply(size);
    size = constraints.apply(size);
    return size;
}

// https://github.com/ziglang/zig/pull/19786
fn handleEvent2(self: *Input, event: events.Event) anyerror!events.EventResult {
    return self.handleEvent(event);
}

pub fn handleEvent(self: *Input, event: events.Event) !events.EventResult {
    if (self.focus_handler.handleEvent(event) == .consumed) {
        return .consumed;
    }

    switch (event) {
        .key, .shift_key => |key| switch (key) {
            .Left => {
                if (self.value.items.len == 0) {
                    return .consumed;
                }
                var left = self.cursor -| 1;
                while (!std.unicode.utf8ValidateSlice(self.value.items[left..self.cursor])) {
                    left -= 1;
                }
                self.cursor = left;
                return .consumed;
            },
            .Right => {
                var right = @min(self.cursor + 1, self.value.items.len);
                while (right < self.value.items.len and !std.unicode.utf8ValidateSlice(self.value.items[self.cursor..right])) {
                    right += 1;
                }
                self.cursor = right;
                return .consumed;
            },
            .Backspace => {
                const old = self.cursor;
                std.debug.assert(try self.handleEvent2(.{ .key = .Left }) == .consumed);
                if (self.cursor != old) {
                    self.value.replaceRangeAssumeCapacity(self.cursor, old - self.cursor, &.{});
                    if (self.on_value_changed) |cb| cb.call(self.value.items);
                }
                return .consumed;
            },
            .Delete => {
                const old = self.cursor;
                std.debug.assert(try self.handleEvent2(.{ .key = .Right }) == .consumed);
                if (self.cursor != old) {
                    self.value.replaceRangeAssumeCapacity(old, self.cursor - old, &.{});
                    self.cursor = old;
                    if (self.on_value_changed) |cb| cb.call(self.value.items);
                }
                return .consumed;
            },
            else => {},
        },

        .char => |char| {
            var cp = std.mem.zeroes([4]u8);
            const cp_len = try std.unicode.utf8Encode(char, &cp);
            try self.value.insertSlice(internal.allocator, self.cursor, cp[0..cp_len]);
            if (self.on_value_changed) |cb| cb.call(self.value.items);
            self.cursor += cp_len;
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
