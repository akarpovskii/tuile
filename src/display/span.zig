const std = @import("std");
const display = @import("../display/display.zig");
const Style = display.Style;

pub const StyledText = struct {
    text: []const u8,

    style: Style,
};

pub const StyledChunk = struct {
    start: usize,

    end: usize,

    style: Style,
};

pub const Span = struct {
    text: std.ArrayList(u8),

    chunks: std.ArrayList(StyledChunk),

    pub fn init(allocator: std.mem.Allocator) Span {
        return Span{
            .text = std.ArrayList(u8).init(allocator),
            .chunks = std.ArrayList(StyledChunk).init(allocator),
        };
    }

    pub fn fromView(allocator: std.mem.Allocator, span_view: SpanView) !Span {
        var self = Span.init(allocator);
        try self.appendSpan(span_view);
        return self;
    }

    pub fn deinit(self: *Span) void {
        self.chunks.deinit();
        self.text.deinit();
    }

    pub fn clone(self: *Span) !Span {
        return Span{
            .text = try self.text.clone(),
            .chunks = try self.chunks.clone(),
        };
    }

    pub fn append(self: *Span, chunk: StyledText) !void {
        const start = self.text.items.len;
        try self.text.appendSlice(chunk.text);
        const end = self.text.items.len;
        try self.chunks.append(StyledChunk{ .start = start, .end = end, .style = chunk.style });
    }

    pub fn appendSlice(self: *Span, chunks: []const StyledText) !void {
        for (chunks) |chunk| {
            try self.append(chunk);
        }
    }

    pub fn appendPlain(self: *Span, text: []const u8) !void {
        try self.append(.{ .text = text, .style = .{} });
    }

    pub fn appendFormat(self: *Span, comptime fmt: []const u8, args: anytype, style: display.Style) !void {
        const start = self.text.items.len;
        try std.fmt.format(self.text.writer(), fmt, args);
        const end = self.text.items.len;
        try self.chunks.append(StyledChunk{ .start = start, .end = end, .style = style });
    }

    pub fn appendSpan(self: *Span, other: anytype) !void {
        const offset = self.text.items.len;
        try self.text.appendSlice(other.getText());
        for (other.getChunks()) |chunk| {
            var new_chunk = chunk;
            new_chunk.start += offset;
            new_chunk.end += offset;
            try self.chunks.append(new_chunk);
        }
    }

    pub fn getText(self: Span) []const u8 {
        return self.text.items;
    }

    pub fn getChunks(self: Span) []const StyledChunk {
        return self.chunks.items;
    }

    pub fn getTextForChunk(self: Span, i: usize) []const u8 {
        const chunk = self.chunks.items[i];
        return self.text.items[chunk.start..chunk.end];
    }

    pub fn getStyleForChunk(self: Span, i: usize) Style {
        const chunk = self.chunks.items[i];
        return chunk.style;
    }

    pub fn view(self: Span) SpanView {
        return SpanView{
            .text = self.text.items,
            .chunks = self.chunks.items,
        };
    }
};

pub const SpanUnmanaged = struct {
    text: std.ArrayListUnmanaged(u8) = .{},

    chunks: std.ArrayListUnmanaged(StyledChunk) = .{},

    pub fn fromView(allocator: std.mem.Allocator, span_view: SpanView) !SpanUnmanaged {
        var self = SpanUnmanaged{};
        try self.appendSpan(allocator, span_view);
        return self;
    }

    pub fn deinit(self: *SpanUnmanaged, allocator: std.mem.Allocator) void {
        self.chunks.deinit(allocator);
        self.text.deinit(allocator);
    }

    pub fn clone(self: *SpanUnmanaged, allocator: std.mem.Allocator) !SpanUnmanaged {
        return SpanUnmanaged{
            .text = try self.text.clone(allocator),
            .chunks = try self.chunks.clone(allocator),
        };
    }

    pub fn append(self: *SpanUnmanaged, allocator: std.mem.Allocator, chunk: StyledText) !void {
        const start = self.text.items.len;
        try self.text.appendSlice(allocator, chunk.text);
        const end = self.text.items.len;
        try self.chunks.append(allocator, StyledChunk{ .start = start, .end = end, .style = chunk.style });
    }

    pub fn appendSlice(self: *SpanUnmanaged, allocator: std.mem.Allocator, chunks: []const StyledText) !void {
        for (chunks) |chunk| {
            try self.append(allocator, chunk);
        }
    }

    pub fn appendPlain(self: *SpanUnmanaged, allocator: std.mem.Allocator, text: []const u8) !void {
        try self.append(allocator, .{ .text = text, .style = .{} });
    }

    pub fn appendFormat(self: *SpanUnmanaged, allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype, style: display.Style) !void {
        const start = self.text.items.len;
        try std.fmt.format(self.text.writer(allocator), fmt, args);
        const end = self.text.items.len;
        try self.chunks.append(allocator, StyledChunk{ .start = start, .end = end, .style = style });
    }

    pub fn appendSpan(self: *SpanUnmanaged, allocator: std.mem.Allocator, other: anytype) !void {
        const offset = self.text.items.len;
        try self.text.appendSlice(allocator, other.getText());
        for (other.getChunks()) |chunk| {
            var new_chunk = chunk;
            new_chunk.start += offset;
            new_chunk.end += offset;
            try self.chunks.append(allocator, new_chunk);
        }
    }

    pub fn getText(self: SpanUnmanaged) []const u8 {
        return self.text.items;
    }

    pub fn getChunks(self: SpanUnmanaged) []const StyledChunk {
        return self.chunks.items;
    }

    pub fn getTextForChunk(self: SpanUnmanaged, i: usize) []const u8 {
        const chunk = self.chunks.items[i];
        return self.text.items[chunk.start..chunk.end];
    }

    pub fn getStyleForChunk(self: SpanUnmanaged, i: usize) Style {
        const chunk = self.chunks.items[i];
        return chunk.style;
    }

    pub fn view(self: SpanUnmanaged) SpanView {
        return SpanView{
            .text = self.text.items,
            .chunks = self.chunks.items,
        };
    }
};

pub const SpanView = struct {
    text: []const u8,

    chunks: []const StyledChunk,

    pub fn getText(self: SpanView) []const u8 {
        return self.text;
    }

    pub fn getChunks(self: SpanView) []const StyledChunk {
        return self.chunks;
    }

    pub fn getTextForChunk(self: SpanView, i: usize) []const u8 {
        const chunk = self.chunks[i];
        return self.text[chunk.start..chunk.end];
    }

    pub fn getStyleForChunk(self: SpanView, i: usize) Style {
        const chunk = self.chunks[i];
        return chunk.style;
    }
};

const expect = std.testing.expect;

test "append plain" {
    var test_span = Span.init(std.testing.allocator);
    defer test_span.deinit();

    try test_span.appendPlain("hello");
    try expect(test_span.getChunks().len == 1);
    try expect(std.mem.eql(u8, test_span.getTextForChunk(0), "hello"));
    try expect(std.mem.eql(u8, test_span.getText(), "hello"));
    try expect(std.meta.eql(test_span.getStyleForChunk(0), Style{}));

    try test_span.appendPlain(" world");
    try expect(test_span.getChunks().len == 2);
    try expect(std.mem.eql(u8, test_span.getTextForChunk(1), " world"));
    try expect(std.mem.eql(u8, test_span.getText(), "hello world"));
    try expect(std.meta.eql(test_span.getStyleForChunk(1), Style{}));
}

test "append styled" {
    var test_span = Span.init(std.testing.allocator);
    defer test_span.deinit();

    var style = Style{ .fg = .{ .bright = .red } };

    try test_span.append(.{ .text = "hello", .style = style });
    try expect(test_span.getChunks().len == 1);
    try expect(std.mem.eql(u8, test_span.getTextForChunk(0), "hello"));
    try expect(std.mem.eql(u8, test_span.getText(), "hello"));
    try expect(std.meta.eql(test_span.getStyleForChunk(0), style));

    style.fg = .{ .bright = .blue };

    try test_span.append(.{ .text = " world", .style = style });
    try expect(test_span.getChunks().len == 2);
    try expect(std.mem.eql(u8, test_span.getTextForChunk(1), " world"));
    try expect(std.mem.eql(u8, test_span.getText(), "hello world"));
    try expect(std.meta.eql(test_span.getStyleForChunk(1), style));
}

test "append slice" {
    var test_span = Span.init(std.testing.allocator);
    defer test_span.deinit();

    const slice: []const StyledText = &.{
        .{ .text = "hello", .style = .{ .fg = .{ .bright = .red } } },
        .{ .text = " world", .style = .{ .fg = .{ .bright = .blue } } },
    };

    try test_span.appendSlice(slice);
    try expect(test_span.getChunks().len == 2);
    try expect(std.mem.eql(u8, test_span.getTextForChunk(0), "hello"));
    try expect(std.mem.eql(u8, test_span.getTextForChunk(1), " world"));
    try expect(std.mem.eql(u8, test_span.getText(), "hello world"));

    try expect(std.meta.eql(test_span.getStyleForChunk(0), slice[0].style));
    try expect(std.meta.eql(test_span.getStyleForChunk(1), slice[1].style));
}

test "append format" {
    var test_span = Span.init(std.testing.allocator);
    defer test_span.deinit();

    const style = Style{ .fg = .{ .bright = .red } };
    try test_span.appendFormat("{d} {s}", .{ 1, "hello" }, style);
    try expect(std.mem.eql(u8, test_span.getText(), "1 hello"));
    try expect(std.mem.eql(u8, test_span.getTextForChunk(0), "1 hello"));
    try expect(std.meta.eql(test_span.getStyleForChunk(0), style));
}

test "unmanaged append plain" {
    var test_span = SpanUnmanaged{};
    defer test_span.deinit(std.testing.allocator);

    try test_span.appendPlain(std.testing.allocator, "hello");
    try expect(test_span.getChunks().len == 1);
    try expect(std.mem.eql(u8, test_span.getTextForChunk(0), "hello"));
    try expect(std.mem.eql(u8, test_span.getText(), "hello"));
    try expect(std.meta.eql(test_span.getStyleForChunk(0), Style{}));

    try test_span.appendPlain(std.testing.allocator, " world");
    try expect(test_span.getChunks().len == 2);
    try expect(std.mem.eql(u8, test_span.getTextForChunk(1), " world"));
    try expect(std.mem.eql(u8, test_span.getText(), "hello world"));
    try expect(std.meta.eql(test_span.getStyleForChunk(1), Style{}));
}

test "unmanaged append styled" {
    var test_span = SpanUnmanaged{};
    defer test_span.deinit(std.testing.allocator);

    var style = Style{ .fg = .{ .bright = .red } };

    try test_span.append(std.testing.allocator, .{ .text = "hello", .style = style });
    try expect(test_span.getChunks().len == 1);
    try expect(std.mem.eql(u8, test_span.getTextForChunk(0), "hello"));
    try expect(std.mem.eql(u8, test_span.getText(), "hello"));
    try expect(std.meta.eql(test_span.getStyleForChunk(0), style));

    style.fg = .{ .bright = .blue };

    try test_span.append(std.testing.allocator, .{ .text = " world", .style = style });
    try expect(test_span.getChunks().len == 2);
    try expect(std.mem.eql(u8, test_span.getTextForChunk(1), " world"));
    try expect(std.mem.eql(u8, test_span.getText(), "hello world"));
    try expect(std.meta.eql(test_span.getStyleForChunk(1), style));
}

test "unmanaged append slice" {
    var test_span = SpanUnmanaged{};
    defer test_span.deinit(std.testing.allocator);

    const slice: []const StyledText = &.{
        .{ .text = "hello", .style = .{ .fg = .{ .bright = .red } } },
        .{ .text = " world", .style = .{ .fg = .{ .bright = .blue } } },
    };

    try test_span.appendSlice(std.testing.allocator, slice);
    try expect(test_span.getChunks().len == 2);
    try expect(std.mem.eql(u8, test_span.getTextForChunk(0), "hello"));
    try expect(std.mem.eql(u8, test_span.getTextForChunk(1), " world"));
    try expect(std.mem.eql(u8, test_span.getText(), "hello world"));

    try expect(std.meta.eql(test_span.getStyleForChunk(0), slice[0].style));
    try expect(std.meta.eql(test_span.getStyleForChunk(1), slice[1].style));
}

test "unmanaged append format" {
    var test_span = SpanUnmanaged{};
    defer test_span.deinit(std.testing.allocator);

    const style = Style{ .fg = .{ .bright = .red } };
    try test_span.appendFormat(std.testing.allocator, "{d} {s}", .{ 1, "hello" }, style);
    try expect(std.mem.eql(u8, test_span.getText(), "1 hello"));
    try expect(std.mem.eql(u8, test_span.getTextForChunk(0), "1 hello"));
    try expect(std.meta.eql(test_span.getStyleForChunk(0), style));
}

test "append managed span to managed span" {
    var span1 = Span.init(std.testing.allocator);
    defer span1.deinit();
    var span2 = Span.init(std.testing.allocator);
    defer span2.deinit();

    const style1 = Style{ .fg = .{ .bright = .red } };
    const style2 = Style{ .fg = .{ .bright = .blue } };

    try span1.append(.{ .text = "hello", .style = style1 });
    try span2.append(.{ .text = " world", .style = style2 });
    try span1.appendSpan(span2);

    try expect(std.mem.eql(u8, span1.getText(), "hello world"));
    try expect(std.mem.eql(u8, span1.getTextForChunk(0), "hello"));
    try expect(std.mem.eql(u8, span1.getTextForChunk(1), " world"));
    try expect(std.meta.eql(span1.getStyleForChunk(0), style1));
    try expect(std.meta.eql(span1.getStyleForChunk(1), style2));
}

test "append unmanaged span to managed span" {
    var span1 = Span.init(std.testing.allocator);
    defer span1.deinit();
    var span2 = SpanUnmanaged{};
    defer span2.deinit(std.testing.allocator);

    const style1 = Style{ .fg = .{ .bright = .red } };
    const style2 = Style{ .fg = .{ .bright = .blue } };

    try span1.append(.{ .text = "hello", .style = style1 });
    try span2.append(std.testing.allocator, .{ .text = " world", .style = style2 });
    try span1.appendSpan(span2);

    try expect(std.mem.eql(u8, span1.getText(), "hello world"));
    try expect(std.mem.eql(u8, span1.getTextForChunk(0), "hello"));
    try expect(std.mem.eql(u8, span1.getTextForChunk(1), " world"));
    try expect(std.meta.eql(span1.getStyleForChunk(0), style1));
    try expect(std.meta.eql(span1.getStyleForChunk(1), style2));
}

test "append managed span to unmanaged span" {
    var span1 = SpanUnmanaged{};
    defer span1.deinit(std.testing.allocator);
    var span2 = Span.init(std.testing.allocator);
    defer span2.deinit();

    const style1 = Style{ .fg = .{ .bright = .red } };
    const style2 = Style{ .fg = .{ .bright = .blue } };

    try span1.append(std.testing.allocator, .{ .text = "hello", .style = style1 });
    try span2.append(.{ .text = " world", .style = style2 });
    try span1.appendSpan(std.testing.allocator, span2);

    try expect(std.mem.eql(u8, span1.getText(), "hello world"));
    try expect(std.mem.eql(u8, span1.getTextForChunk(0), "hello"));
    try expect(std.mem.eql(u8, span1.getTextForChunk(1), " world"));
    try expect(std.meta.eql(span1.getStyleForChunk(0), style1));
    try expect(std.meta.eql(span1.getStyleForChunk(1), style2));
}

test "append unmanaged span to unmanaged span" {
    var span1 = SpanUnmanaged{};
    defer span1.deinit(std.testing.allocator);
    var span2 = SpanUnmanaged{};
    defer span2.deinit(std.testing.allocator);

    const style1 = Style{ .fg = .{ .bright = .red } };
    const style2 = Style{ .fg = .{ .bright = .blue } };

    try span1.append(std.testing.allocator, .{ .text = "hello", .style = style1 });
    try span2.append(std.testing.allocator, .{ .text = " world", .style = style2 });
    try span1.appendSpan(std.testing.allocator, span2);

    try expect(std.mem.eql(u8, span1.getText(), "hello world"));
    try expect(std.mem.eql(u8, span1.getTextForChunk(0), "hello"));
    try expect(std.mem.eql(u8, span1.getTextForChunk(1), " world"));
    try expect(std.meta.eql(span1.getStyleForChunk(0), style1));
    try expect(std.meta.eql(span1.getStyleForChunk(1), style2));
}

test "view of managed span" {
    var test_span = Span.init(std.testing.allocator);
    defer test_span.deinit();

    const slice: []const StyledText = &.{
        .{ .text = "hello", .style = .{ .fg = .{ .bright = .red } } },
        .{ .text = " world", .style = .{ .fg = .{ .bright = .blue } } },
    };

    try test_span.appendSlice(slice);

    const span_view = test_span.view();
    try expect(std.mem.eql(u8, span_view.getTextForChunk(0), "hello"));
    try expect(std.mem.eql(u8, span_view.getTextForChunk(1), " world"));
    try expect(std.mem.eql(u8, span_view.getText(), "hello world"));

    try expect(std.meta.eql(span_view.getStyleForChunk(0), slice[0].style));
    try expect(std.meta.eql(span_view.getStyleForChunk(1), slice[1].style));
}

test "view of unmanaged span" {
    var test_span = SpanUnmanaged{};
    defer test_span.deinit(std.testing.allocator);

    const slice: []const StyledText = &.{
        .{ .text = "hello", .style = .{ .fg = .{ .bright = .red } } },
        .{ .text = " world", .style = .{ .fg = .{ .bright = .blue } } },
    };

    try test_span.appendSlice(std.testing.allocator, slice);

    const span_view = test_span.view();
    try expect(std.mem.eql(u8, span_view.getTextForChunk(0), "hello"));
    try expect(std.mem.eql(u8, span_view.getTextForChunk(1), " world"));
    try expect(std.mem.eql(u8, span_view.getText(), "hello world"));

    try expect(std.meta.eql(span_view.getStyleForChunk(0), slice[0].style));
    try expect(std.meta.eql(span_view.getStyleForChunk(1), slice[1].style));
}

test "managed span from view" {
    var span = Span.init(std.testing.allocator);
    defer span.deinit();

    const slice: []const StyledText = &.{
        .{ .text = "hello", .style = .{ .fg = .{ .bright = .red } } },
        .{ .text = " world", .style = .{ .fg = .{ .bright = .blue } } },
    };
    try span.appendSlice(slice);

    const span_view = span.view();

    var span2 = try Span.fromView(std.testing.allocator, span_view);
    defer span2.deinit();

    try expect(std.mem.eql(u8, span.getText(), span2.getText()));
    for (span.getChunks(), span2.getChunks()) |chunk1, chunk2| {
        try expect(std.meta.eql(chunk1, chunk2));
    }
}

test "unmanaged span from view" {
    var span = SpanUnmanaged{};
    defer span.deinit(std.testing.allocator);

    const slice: []const StyledText = &.{
        .{ .text = "hello", .style = .{ .fg = .{ .bright = .red } } },
        .{ .text = " world", .style = .{ .fg = .{ .bright = .blue } } },
    };
    try span.appendSlice(std.testing.allocator, slice);

    const span_view = span.view();

    var span2 = try SpanUnmanaged.fromView(std.testing.allocator, span_view);
    defer span2.deinit(std.testing.allocator);

    try expect(std.mem.eql(u8, span.getText(), span2.getText()));
    for (span.getChunks(), span2.getChunks()) |chunk1, chunk2| {
        try expect(std.meta.eql(chunk1, chunk2));
    }
}
