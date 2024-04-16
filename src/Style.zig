const std = @import("std");

const Style = @This();

border: Border = .Dashed,

pub const Border = enum {
    None,
    Dashed,
};

pub const Effect = enum {
    None,
    Highlight,
    Underline,
    Reverse,
    Blink,
    Dim,
    Bold,
};
