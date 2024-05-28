const std = @import("std");
const builtin = @import("builtin");
const root = @import("root");
const grapheme = @import("grapheme");
const DisplayWidth = @import("DisplayWidth");

const default_allocator = blk: {
    if (@hasDecl(root, "tuile_allocator")) {
        break :blk root.tuile_allocator;
    } else if (builtin.is_test) {
        break :blk std.testing.allocator;
    } else if (builtin.link_libc) {
        break :blk std.heap.c_allocator;
    } else {
        break :blk std.heap.page_allocator;
    }
};

pub const allocator = default_allocator;

pub var gd: grapheme.GraphemeData = undefined;
pub var dwd: DisplayWidth.DisplayWidthData = undefined;

pub fn init() !void {
    gd = try grapheme.GraphemeData.init(allocator);
    dwd = try DisplayWidth.DisplayWidthData.init(allocator);
}

pub fn deinit() void {
    dwd.deinit();
    gd.deinit();
}
