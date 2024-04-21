const std = @import("std");

min_width: u32 = 0,

min_height: u32 = 0,

max_width: u32 = std.math.maxInt(u32),

max_height: u32 = std.math.maxInt(u32),

flex: u32 = 0,

alignment: Align = Align.center(),

pub const Align = struct {
    h: HAlign,
    v: VAlign,

    pub fn topLeft() Align {
        return .{ .h = .left, .v = .top };
    }

    pub fn topCenter() Align {
        return .{ .h = .center, .v = .top };
    }

    pub fn topRight() Align {
        return .{ .h = .right, .v = .top };
    }

    pub fn centerLeft() Align {
        return .{ .h = .left, .v = .center };
    }

    pub fn center() Align {
        return .{ .h = .center, .v = .center };
    }

    pub fn centerRight() Align {
        return .{ .h = .right, .v = .center };
    }

    pub fn bottomLeft() Align {
        return .{ .h = .left, .v = .bottom };
    }

    pub fn bottomCenter() Align {
        return .{ .h = .center, .v = .bottom };
    }

    pub fn bottomRight() Align {
        return .{ .h = .right, .v = .bottom };
    }
};

pub const HAlign = enum {
    left,
    center,
    right,
};

pub const VAlign = enum {
    top,
    center,
    bottom,
};
