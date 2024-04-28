const std = @import("std");
const internal = @import("../internal.zig");
const Widget = @import("Widget.zig");
const Vec2 = @import("../Vec2.zig");
const Rect = @import("../Rect.zig");
const events = @import("../events.zig");
const Frame = @import("../render/Frame.zig");
const LayoutProperties = @import("LayoutProperties.zig");
const Constraints = @import("Constraints.zig");
const display = @import("../display/display.zig");

const PartialChunk = struct {
    orig: usize,

    start: usize,

    end: usize,
};

const Row = struct {
    chunks: std.ArrayListUnmanaged(PartialChunk) = .{},

    pub fn deinit(self: *Row, allocator: std.mem.Allocator) void {
        self.chunks.deinit(allocator);
    }
};

pub const Config = struct {
    // text and span are mutually exclusive, only one of them must be defined
    text: ?[]const u8 = null,

    // text and span are mutually exclusive, only one of them must be defined
    span: ?display.SpanView = null,

    layout: LayoutProperties = .{},
};

pub const Label = @This();

pub usingnamespace Widget.LeafWidget.Mixin(Label);

content: display.SpanUnmanaged,

rows: std.ArrayListUnmanaged(Row),

layout_properties: LayoutProperties,

pub fn create(config: Config) !*Label {
    if (config.text == null and config.span == null) {
        @panic("text and span are mutually exclusive, only one of them must be defined");
    }
    const self = try internal.allocator.create(Label);
    self.* = Label{
        .content = display.SpanUnmanaged{},
        .rows = .{},
        .layout_properties = config.layout,
    };
    if (config.text) |text| {
        try self.content.appendPlain(internal.allocator, text);
    } else if (config.span) |span| {
        try self.content.appendSpan(internal.allocator, span);
    }
    return self;
}

pub fn destroy(self: *Label) void {
    for (self.rows.items) |*row| {
        row.deinit(internal.allocator);
    }
    self.rows.deinit(internal.allocator);
    self.content.deinit(internal.allocator);
    internal.allocator.destroy(self);
}

pub fn widget(self: *Label) Widget {
    return Widget.init(self);
}

pub fn setText(self: *Label, text: []const u8) !void {
    self.content.deinit(internal.allocator);
    self.content = display.SpanUnmanaged{};
    try self.content.appendPlain(internal.allocator, text);
}

pub fn setSpan(self: *Label, span: display.SpanView) !void {
    self.content.deinit(internal.allocator);
    self.content = try display.SpanUnmanaged.fromView(internal.allocator, span);
}

pub fn render(self: *Label, area: Rect, frame: Frame, _: display.Theme) !void {
    const rows = self.rows.items;
    for (0..area.height()) |y| {
        if (y >= rows.len) break;

        const row = rows[y];
        var pos = area.min.add(.{ .x = 0, .y = @intCast(y) });
        for (row.chunks.items) |chunk| {
            const text = self.content.getTextForChunk(chunk.orig)[chunk.start..chunk.end];
            const written: u32 = @intCast(try frame.writeSymbols(pos, text, area.width()));
            const chunk_area = Rect{ .min = pos, .max = pos.add(.{ .x = written, .y = 1 }) };
            frame.setStyle(chunk_area, self.content.getStyleForChunk(chunk.orig));
            pos.x += written;
        }
    }
}

pub fn layout(self: *Label, constraints: Constraints) !Vec2 {
    try self.wrapText(constraints);

    var max_len: usize = 0;
    for (self.rows.items) |row| {
        var len: usize = 0;
        for (row.chunks.items) |chunk| {
            const text = self.content.getTextForChunk(chunk.orig)[chunk.start..chunk.end];
            len += try std.unicode.utf8CountCodepoints(text);
        }
        max_len = @max(max_len, len);
    }

    var size = Vec2{
        .x = @intCast(max_len),
        .y = @intCast(self.rows.items.len),
    };

    const self_constraints = Constraints.fromProps(self.layout_properties);
    size = self_constraints.apply(size);
    size = constraints.apply(size);
    return size;
}

pub fn handleEvent(_: *Label, _: events.Event) !events.EventResult {
    return .ignored;
}

pub fn layoutProps(self: *Label) LayoutProperties {
    return self.layout_properties;
}

fn wrapText(self: *Label, _: Constraints) !void {
    for (self.rows.items) |*row| {
        row.deinit(internal.allocator);
    }
    self.rows.clearAndFree(internal.allocator);

    for (0..self.content.getChunks().len) |chunk_idx| {
        if (self.rows.items.len == 0) {
            try self.rows.append(internal.allocator, .{});
        }

        const text = self.content.getTextForChunk(chunk_idx);
        var iter = std.mem.tokenizeScalar(u8, text, '\n');
        while (iter.next()) |line| {
            const start = @intFromPtr(line.ptr) - @intFromPtr(text.ptr);
            const end = start + line.len;
            const partial = PartialChunk{
                .orig = chunk_idx,
                .start = start,
                .end = end,
            };

            var last = &self.rows.items[self.rows.items.len - 1];
            try last.chunks.append(internal.allocator, partial);
            if (iter.peek()) |_| {
                try self.rows.append(internal.allocator, .{});
            }
        }
        // tokenize skips delimiters, but we need to add another row
        // if newline happens to be at the end
        if (text.len > 0 and text[text.len - 1] == '\n') {
            try self.rows.append(internal.allocator, .{});
        }
    }
}
