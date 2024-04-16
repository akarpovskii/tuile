const std = @import("std");

const Style = @This();

border: Border = Border.Solid,

pub const Border = struct {
    top: []const u8,
    bottom: []const u8,
    left: []const u8,
    right: []const u8,
    top_left: []const u8,
    top_right: []const u8,
    bottom_left: []const u8,
    bottom_right: []const u8,

    pub const None = .{};

    pub const Dashed: Border = .{
        .top = "-",
        .bottom = "-",
        .left = "|",
        .right = "|",
        .top_left = "+",
        .top_right = "+",
        .bottom_left = "+",
        .bottom_right = "+",
    };

    pub const Solid: Border = .{
        .top = "─",
        .bottom = "─",
        .left = "│",
        .right = "│",
        .top_left = "┌",
        .top_right = "┐",
        .bottom_left = "└",
        .bottom_right = "┘",
    };
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
