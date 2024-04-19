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

    pub fn top_left() Align {
        return .{ .h = .left, .v = .top };
    }

    pub fn top_center() Align {
        return .{ .h = .center, .v = .top };
    }

    pub fn top_right() Align {
        return .{ .h = .right, .v = .top };
    }

    pub fn center_left() Align {
        return .{ .h = .left, .v = .center };
    }

    pub fn center() Align {
        return .{ .h = .center, .v = .center };
    }

    pub fn center_right() Align {
        return .{ .h = .right, .v = .center };
    }

    pub fn bottom_left() Align {
        return .{ .h = .left, .v = .bottom };
    }

    pub fn bottom_center() Align {
        return .{ .h = .center, .v = .bottom };
    }

    pub fn bottom_right() Align {
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
