const std = @import("std");
const grapheme = @import("grapheme");
const DisplayWidth = @import("DisplayWidth");
const internal = @import("internal.zig");

pub const TextCluster = struct {
    len: u8,
    offset: usize,
    display_width: usize,

    pub fn bytes(self: TextCluster, src: []const u8) []const u8 {
        return src[self.offset..][0..self.len];
    }
};

pub const GraphemeClusterIterator = struct {
    bytes: []const u8,
    impl: grapheme.Iterator,
    dw: DisplayWidth,

    pub fn init(bytes: []const u8) !GraphemeClusterIterator {
        // grapheme.Iterator doesn't validate the slice
        // though at this point it should be valid?
        if (!std.unicode.utf8ValidateSlice(bytes)) {
            return error.InvalidUtf8;
        }
        return GraphemeClusterIterator{
            .bytes = bytes,
            .impl = grapheme.Iterator.init(bytes, &internal.gd),
            .dw = DisplayWidth{ .data = &internal.dwd },
        };
    }

    pub fn next(self: *GraphemeClusterIterator) ?TextCluster {
        if (self.impl.next()) |gc| {
            return TextCluster{
                .len = gc.len,
                .offset = gc.offset,
                .display_width = self.dw.strWidth(gc.bytes(self.bytes)),
            };
        } else {
            return null;
        }
    }
};

pub const CodepointClusterIterator = struct {
    cp_iter: std.unicode.Utf8Iterator,

    pub fn init(bytes: []const u8) !CodepointClusterIterator {
        const view = try std.unicode.Utf8View.init(bytes);
        return CodepointClusterIterator{
            .cp_iter = view.iterator(),
        };
    }

    pub fn next(self: *CodepointClusterIterator) ?TextCluster {
        if (self.cp_iter.nextCodepointSlice()) |slice_const| {
            var slice = slice_const;
            const cp = std.unicode.utf8Decode(slice) catch @panic("string was checked when constructing the iterator");
            const width: usize = @intCast(@max(0, internal.dwd.codePointWidth(cp)));

            // Put the following zero-width codepoints in the same cluster
            var next_slice = self.cp_iter.peek(1);
            while (next_slice.len > 0) {
                const next_cp = std.unicode.utf8Decode(next_slice) catch @panic("string was checked when constructing the iterator");
                const next_width: usize = @intCast(@max(0, internal.dwd.codePointWidth(next_cp)));
                if (next_width > 0) {
                    break;
                }
                slice.len += next_slice.len;
                self.cp_iter.i += next_slice.len;
                next_slice = self.cp_iter.peek(1);
            }

            return TextCluster{
                .len = @intCast(slice.len),
                .offset = @intFromPtr(slice.ptr) - @intFromPtr(self.cp_iter.bytes.ptr),
                .display_width = width,
            };
        } else {
            return null;
        }
    }
};

pub const ClusteringType = enum {
    graphemes,
    codepoints,
};

pub const ClusterIterator = union(ClusteringType) {
    graphemes: GraphemeClusterIterator,
    codepoints: CodepointClusterIterator,

    pub fn init(clustering: ClusteringType, bytes: []const u8) !ClusterIterator {
        return switch (clustering) {
            .graphemes => .{ .graphemes = try GraphemeClusterIterator.init(bytes) },
            .codepoints => .{ .codepoints = try CodepointClusterIterator.init(bytes) },
        };
    }

    pub fn next(self: *ClusterIterator) ?TextCluster {
        return switch (self.*) {
            .graphemes => |*iter| iter.next(),
            .codepoints => |*iter| iter.next(),
        };
    }
};

pub fn stringDisplayWidth(bytes: []const u8, clustering: ClusteringType) !usize {
    var width: usize = 0;
    var iter = try ClusterIterator.init(clustering, bytes);
    while (iter.next()) |cluster| {
        width += cluster.display_width;
    }
    return width;
}

test "codepoints cluster iterator" {
    try internal.init();
    defer internal.deinit();
    var iter = try ClusterIterator.init(.codepoints, "\xF0\x9F\x91\x8D\xF0\x9F\x8F\xBD");
    const cp1 = iter.next();
    try std.testing.expect(cp1 != null);
    try std.testing.expectEqualStrings(cp1.?.bytes, "\xF0\x9F\x91\x8D");

    const cp2 = iter.next();
    try std.testing.expect(cp2 != null);
    try std.testing.expectEqualStrings(cp2.?.bytes, "\xF0\x9F\x8F\xBD");
}

test "graphemes cluster iterator" {
    try internal.init();
    defer internal.deinit();
    var iter = try ClusterIterator.init(.graphemes, "\xF0\x9F\x91\x8D\xF0\x9F\x8F\xBD");
    const cp1 = iter.next();
    try std.testing.expect(cp1 != null);
    try std.testing.expectEqualStrings(cp1.?.bytes, "\xF0\x9F\x91\x8D\xF0\x9F\x8F\xBD");

    const cp2 = iter.next();
    try std.testing.expect(cp2 == null);
}

test "string display width" {
    try internal.init();
    defer internal.deinit();
    try std.testing.expectEqual(4, try stringDisplayWidth("\xF0\x9F\x91\x8D\xF0\x9F\x8F\xBD", .codepoints));
    try std.testing.expectEqual(2, try stringDisplayWidth("\xF0\x9F\x91\x8D\xF0\x9F\x8F\xBD", .graphemes));
}
