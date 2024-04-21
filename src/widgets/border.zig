pub const Border = struct {
    top: bool = false,
    right: bool = false,
    bottom: bool = false,
    left: bool = false,

    pub fn none() Border {
        return .{};
    }

    pub fn all() Border {
        return .{ .top = true, .right = true, .bottom = true, .left = true };
    }
};

pub const BorderType = enum {
    simple,
    solid,
    rounded,
    double,
    thick,
};

pub const BorderCharacters = struct {
    top: []const u8,
    bottom: []const u8,
    left: []const u8,
    right: []const u8,
    top_left: []const u8,
    top_right: []const u8,
    bottom_left: []const u8,
    bottom_right: []const u8,

    pub fn fromType(border: BorderType) BorderCharacters {
        return switch (border) {
            .simple => .{
                .top = "-",
                .bottom = "-",
                .left = "|",
                .right = "|",
                .top_left = "+",
                .top_right = "+",
                .bottom_left = "+",
                .bottom_right = "+",
            },
            .solid => .{
                .top = "─",
                .bottom = "─",
                .left = "│",
                .right = "│",
                .top_left = "┌",
                .top_right = "┐",
                .bottom_left = "└",
                .bottom_right = "┘",
            },
            .rounded => .{
                .top = "─",
                .bottom = "─",
                .left = "│",
                .right = "│",
                .top_left = "╭",
                .top_right = "╮",
                .bottom_left = "╰",
                .bottom_right = "╯",
            },
            .double => .{
                .top = "═",
                .bottom = "═",
                .left = "║",
                .right = "║",
                .top_left = "╔",
                .top_right = "╗",
                .bottom_left = "╚",
                .bottom_right = "╝",
            },
            .thick => .{
                .top = "━",
                .bottom = "━",
                .left = "┃",
                .right = "┃",
                .top_left = "┏",
                .top_right = "┓",
                .bottom_left = "┗",
                .bottom_right = "┛",
            },
        };
    }
};
