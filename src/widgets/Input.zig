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
const text_clustering = @import("../text_clustering.zig");
const TextCluster = text_clustering.TextCluster;
const stringDisplayWidth = text_clustering.stringDisplayWidth;
const ClusterIterator = text_clustering.ClusterIterator;
const GraphemeClusterIterator = text_clustering.GraphemeClusterIterator;

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

graphemes: std.ArrayListUnmanaged(TextCluster),

grapheme_cursor: u32 = 0,

view_start: usize = 0,

pub fn create(config: Config) !*Input {
    const self = try internal.allocator.create(Input);
    self.* = Input{
        .widget_base = try Widget.Base.init(config.id),
        .on_value_changed = config.on_value_changed,
        .placeholder = try internal.allocator.dupe(u8, config.placeholder),
        .value = std.ArrayListUnmanaged(u8){},
        .layout_properties = config.layout,
        .graphemes = std.ArrayListUnmanaged(TextCluster){},
    };
    try self.graphemes.append(internal.allocator, TextCluster{ .offset = 0, .len = 0, .display_width = 0 });
    return self;
}

pub fn destroy(self: *Input) void {
    self.widget_base.deinit();
    self.graphemes.deinit(internal.allocator);
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
    try self.rebuildGraphemes(0);
    self.grapheme_cursor = @intCast(self.graphemes.items.len -| 1);
}

fn cursor(self: Input) usize {
    return self.graphemes.items[self.grapheme_cursor].offset;
}

pub fn render(self: *Input, area: Rect, frame: Frame, theme: display.Theme) !void {
    if (area.height() < 1) {
        return;
    }
    frame.setStyle(area, .{ .bg = theme.interactive, .add_effect = .{ .underline = true } });
    self.focus_handler.render(area, frame, theme);

    const render_placeholder = self.value.items.len == 0;
    if (render_placeholder) frame.setStyle(area, .{ .fg = theme.text_secondary });

    _ = try frame.writeSymbols(area.min, self.visibleText(), area.width());

    if (self.focus_handler.focused) {
        var cursor_pos = area.min;
        const current_text = self.currentText();
        cursor_pos.x += @intCast(try stringDisplayWidth(
            current_text[self.view_start..self.cursor()],
            internal.text_clustering_type,
        ));
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
    if (self.cursor() < self.view_start) {
        self.view_start = self.cursor();
    } else {
        const max_width = std.math.clamp(self.layout_properties.max_width, constraints.min_width, constraints.max_width);
        // +1 is for the cursor itself
        const visible_text = self.currentText()[self.view_start..self.cursor()];
        var visible = try stringDisplayWidth(visible_text, internal.text_clustering_type) + 1;
        if (visible > max_width) {
            var iter = try ClusterIterator.init(internal.text_clustering_type, visible_text);
            while (iter.next()) |cluster| {
                self.view_start += cluster.len;
                visible -= 1;
                if (visible <= max_width) {
                    break;
                }
            }
        }
    }

    const visible = self.visibleText();
    // +1 for the cursor
    const len = try stringDisplayWidth(visible, internal.text_clustering_type) + 1;

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
                if (self.grapheme_cursor > 0) {
                    self.grapheme_cursor -= 1;
                }
                return .consumed;
            },
            .Right => {
                if (self.grapheme_cursor + 1 < self.graphemes.items.len) {
                    self.grapheme_cursor += 1;
                }
                return .consumed;
            },
            .Backspace => {
                if (self.grapheme_cursor > 0) {
                    // Delete by code points é -> e
                    const target_idx = self.grapheme_cursor - 1;
                    const target = self.graphemes.items[target_idx];
                    var cp_cursor = target.offset + target.len - 1;
                    while (cp_cursor >= target.offset) {
                        if (std.unicode.utf8ValidateSlice(self.value.items[cp_cursor .. target.offset + target.len])) {
                            break;
                        }
                        cp_cursor -= 1;
                    }
                    const dl: u8 = target.len - @as(u8, @intCast(cp_cursor - target.offset));
                    self.graphemes.items[target_idx].len -= dl;
                    self.value.replaceRangeAssumeCapacity(cp_cursor, dl, &.{});
                    for (self.grapheme_cursor..self.graphemes.items.len) |i| {
                        self.graphemes.items[i].offset -= dl;
                    }
                    if (self.graphemes.items[target_idx].len == 0) {
                        _ = self.graphemes.orderedRemove(target_idx);
                        self.grapheme_cursor -= 1;
                    }
                    if (self.on_value_changed) |cb| cb.call(self.value.items);
                }
                return .consumed;
            },
            .Delete => {
                if (self.grapheme_cursor < self.graphemes.items.len - 1) {
                    const gr = self.graphemes.items[self.grapheme_cursor];
                    self.value.replaceRangeAssumeCapacity(gr.offset, gr.len, &.{});
                    _ = self.graphemes.orderedRemove(self.grapheme_cursor);
                    for (self.grapheme_cursor..self.graphemes.items.len) |i| {
                        self.graphemes.items[i].offset -= gr.len;
                    }
                    if (self.on_value_changed) |cb| cb.call(self.value.items);
                }
                return .consumed;
            },
            else => {},
        },

        .char => |char| {
            var cp = std.mem.zeroes([4]u8);
            const cp_len = try std.unicode.utf8Encode(char, &cp);
            try self.value.insertSlice(internal.allocator, self.cursor(), cp[0..cp_len]);
            // TODO: Optimize
            try self.rebuildGraphemes(self.graphemes.items[self.grapheme_cursor].offset + cp_len);

            if (self.on_value_changed) |cb| cb.call(self.value.items);
            return .consumed;
        },
        else => {},
    }
    return .ignored;
}

fn rebuildGraphemes(self: *Input, byte_cursor_position: usize) !void {
    // const cursor_offset = self.graphemes.items[self.grapheme_cursor].offset;
    self.graphemes.deinit(internal.allocator);
    self.graphemes = std.ArrayListUnmanaged(TextCluster){};
    var iter = try GraphemeClusterIterator.init(self.value.items);
    while (iter.next()) |gc| {
        try self.graphemes.append(internal.allocator, gc);
    }

    try self.graphemes.append(internal.allocator, TextCluster{
        .offset = if (self.graphemes.getLastOrNull()) |last| last.offset + last.len else 0,
        .len = 0,
        .display_width = 0,
    });

    self.grapheme_cursor = 0;
    for (self.graphemes.items, 0..) |gc, i| {
        if (gc.offset <= byte_cursor_position) {
            self.grapheme_cursor = @intCast(i);
        } else {
            break;
        }
    }
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
