const std = @import("std");

const Style = @This();

border: Border = .Dashed,

pub const Border = enum {
    None,
    Dashed,
};
