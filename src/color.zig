const std = @import("std");

pub const BaseColor = enum {
    black,
    red,
    green,
    yellow,
    blue,
    magenta,
    cyan,
    white,
};

pub const Rgb = struct {
    r: u8,
    g: u8,
    b: u8,

    pub fn black() Rgb {
        return .{ .r = 0, .g = 0, .b = 0 };
    }

    pub fn red() Rgb {
        return .{ .r = 255, .g = 0, .b = 0 };
    }

    pub fn green() Rgb {
        return .{ .r = 0, .g = 255, .b = 0 };
    }

    pub fn yellow() Rgb {
        return .{ .r = 255, .g = 255, .b = 0 };
    }

    pub fn blue() Rgb {
        return .{ .r = 0, .g = 0, .b = 255 };
    }

    pub fn magenta() Rgb {
        return .{ .r = 255, .g = 0, .b = 255 };
    }

    pub fn cyan() Rgb {
        return .{ .r = 0, .g = 255, .b = 255 };
    }

    pub fn white() Rgb {
        return .{ .r = 255, .g = 255, .b = 255 };
    }
};

pub const Color = union(enum) {
    dark: BaseColor,
    bright: BaseColor,
    rgb: Rgb,
};

pub const ColorPair = struct {
    fg: Color,
    bg: Color,
};

pub const Palette256 = struct {
    pub const lookup_table: [256][3]u8 = init_lut: {
        var palette: [256][3]u8 = undefined;

        palette[0] = .{ 0, 0, 0 };
        palette[1] = .{ 128, 0, 0 };
        palette[2] = .{ 0, 128, 0 };
        palette[3] = .{ 128, 128, 0 };
        palette[4] = .{ 0, 0, 128 };
        palette[5] = .{ 128, 0, 128 };
        palette[6] = .{ 0, 128, 128 };
        palette[7] = .{ 192, 192, 192 };
        palette[8] = .{ 128, 128, 128 };
        palette[9] = .{ 255, 0, 0 };
        palette[10] = .{ 0, 255, 0 };
        palette[11] = .{ 255, 255, 0 };
        palette[12] = .{ 0, 0, 255 };
        palette[13] = .{ 255, 0, 255 };
        palette[14] = .{ 0, 255, 255 };
        palette[15] = .{ 255, 255, 255 };

        for (16..256) |idx| {
            if (idx < 232) {
                const i = idx - 16;
                const steps = [_]u8{ 0, 95, 135, 175, 215, 255 };
                palette[idx] = .{
                    steps[i / 36],
                    steps[(i / 6) % 6],
                    steps[i % 6],
                };
            } else {
                // 232..256 represent grayscale from dark to light in 24 steps
                // from black 8 to almost white 238 with step 10
                const start = 8;
                const step = 10;
                const grayscale = start + step * (idx - 232);
                palette[idx] = .{
                    grayscale,
                    grayscale,
                    grayscale,
                };
            }
        }

        break :init_lut palette;
    };

    // Uses Manhatten distance to find the closest color
    pub fn findClosest(rgb: Rgb) u8 {
        return findClosestInRange(rgb, 0, null);
    }

    // Uses Manhatten distance to find the closest color
    // Ignores the first 16 colors
    pub fn findClosestNonSystem(rgb: Rgb) u8 {
        return findClosestInRange(rgb, 16, null);
    }

    // Uses Manhatten distance to find the closest color of the first 16
    pub fn findClosestSystem(rgb: Rgb) u8 {
        return findClosestInRange(rgb, 0, 16);
    }

    // Uses Manhatten distance to find the closest color
    pub fn findClosestInRange(rgb: Rgb, start: u8, end: ?u8) u8 {
        var lut_idx: u8 = start;
        var distance: u32 = std.math.maxInt(u32);
        const needle: [3]u8 = .{ rgb.r, rgb.g, rgb.b };

        for (lookup_table[start .. end orelse lookup_table.len], start..) |palette_color, idx| {
            var new_distance: u32 = 0;
            for (palette_color, needle) |a, b| {
                new_distance += @abs(@as(i32, a) - @as(i32, b));
            }
            if (new_distance < distance) {
                distance = new_distance;
                lut_idx = @intCast(idx);
            }
        }
        return lut_idx;
    }
};
