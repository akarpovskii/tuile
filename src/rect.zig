const Vec2 = @import("vec2.zig").Vec2;
const LayoutProperties = @import("widgets/LayoutProperties.zig");
const Align = LayoutProperties.Align;
const HAlign = LayoutProperties.HAlign;
const VAlign = LayoutProperties.VAlign;

pub fn Rect(T: type) type {
    return struct {
        const Self = @This();

        min: Vec2(T),

        max: Vec2(T),

        pub fn intersect(self: Self, other: Self) Self {
            return Self{
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

        pub fn width(self: Self) i32 {
            return self.max.x - self.min.x;
        }

        pub fn height(self: Self) i32 {
            return self.max.y - self.min.y;
        }

        pub fn diag(self: Self) Vec2(T) {
            return self.max.sub(self.min);
        }

        /// Centers other inside self horizontally
        pub fn alignH(self: Self, alignment: HAlign, other: Self) Self {
            var min = Vec2(T){
                .x = self.min.x,
                .y = other.min.y,
            };
            switch (alignment) {
                .left => {},
                .center => min.x += @divTrunc(self.width() - other.width(), 2),
                .right => min.x = self.max.x - other.width(),
            }
            return Self{ .min = min, .max = min.add(other.diag()) };
        }

        /// Centers other inside self vertically
        pub fn alignV(self: Self, alignment: VAlign, other: Self) Self {
            var min = Vec2(T){
                .x = other.min.x,
                .y = self.min.y,
            };
            switch (alignment) {
                .top => {},
                .center => min.y += @divTrunc(self.height() - other.height(), 2),
                .bottom => min.y = self.max.y - other.height(),
            }
            return Self{ .min = min, .max = min.add(other.diag()) };
        }

        /// Centers other inside self both horizontally and vertically
        pub fn alignInside(self: Self, alignment: Align, other: Self) Self {
            const h = self.alignH(alignment.h, other);
            const v = self.alignV(alignment.v, h);
            return v;
        }
    };
}
