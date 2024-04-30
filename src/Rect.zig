const Vec2 = @import("Vec2.zig");
const LayoutProperties = @import("widgets/LayoutProperties.zig");
const Align = LayoutProperties.Align;
const HAlign = LayoutProperties.HAlign;
const VAlign = LayoutProperties.VAlign;

const Rect = @This();

min: Vec2,

max: Vec2,

pub fn intersect(self: Rect, other: Rect) Rect {
    return Rect{
        .min = .{
            .x = @max(self.min.x, other.min.x),
            .y = @max(self.min.y, other.min.y),
        },
        .max = .{
            .x = @min(self.max.x, other.max.x),
            .y = @min(self.max.y, other.max.y),
        },
    };
}

pub fn width(self: Rect) u32 {
    return self.max.x - self.min.x;
}

pub fn height(self: Rect) u32 {
    return self.max.y - self.min.y;
}

pub fn diag(self: Rect) Vec2 {
    return self.max.sub(self.min);
}

/// Other area must fit inside this area, otherwise the result will be clamped
pub fn alignH(self: Rect, alignment: HAlign, other: Rect) Rect {
    var min = Vec2{
        .x = self.min.x,
        .y = other.min.y,
    };
    switch (alignment) {
        .left => {},
        .center => min.x += (self.width() -| other.width()) / 2,
        .right => min.x = self.max.x -| other.width(),
    }
    return Rect{ .min = min, .max = min.add(other.diag()) };
}

/// Other area must fit inside this area, otherwise the result will be clamped
pub fn alignV(self: Rect, alignment: VAlign, other: Rect) Rect {
    var min = Vec2{
        .x = other.min.x,
        .y = self.min.y,
    };
    switch (alignment) {
        .top => {},
        .center => min.y += (self.height() -| other.height()) / 2,
        .bottom => min.y = self.max.y -| other.height(),
    }
    return Rect{ .min = min, .max = min.add(other.diag()) };
}

/// Other area must fit inside this area, otherwise the result will be clamped
pub fn alignInside(self: Rect, alignment: Align, other: Rect) Rect {
    const h = self.alignH(alignment.h, other);
    const v = self.alignV(alignment.v, h);
    return v;
}
