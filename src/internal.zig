const std = @import("std");
const builtin = @import("builtin");
const root = @import("root");

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
