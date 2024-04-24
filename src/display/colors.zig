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

    pub fn fromString(str: []const u8) error{UnrecognizedColor}!Color {
        const eql = std.ascii.eqlIgnoreCase;
        if (eql(str, "dark black")) return .{ .dark = .black };
        if (eql(str, "dark red")) return .{ .dark = .red };
        if (eql(str, "dark green")) return .{ .dark = .green };
        if (eql(str, "dark yellow")) return .{ .dark = .yellow };
        if (eql(str, "dark blue")) return .{ .dark = .blue };
        if (eql(str, "dark magenta")) return .{ .dark = .magenta };
        if (eql(str, "dark cyan")) return .{ .dark = .cyan };
        if (eql(str, "dark white")) return .{ .dark = .white };

        if (eql(str, "bright black")) return .{ .bright = .black };
        if (eql(str, "bright red")) return .{ .bright = .red };
        if (eql(str, "bright green")) return .{ .bright = .green };
        if (eql(str, "bright yellow")) return .{ .bright = .yellow };
        if (eql(str, "bright blue")) return .{ .bright = .blue };
        if (eql(str, "bright magenta")) return .{ .bright = .magenta };
        if (eql(str, "bright cyan")) return .{ .bright = .cyan };
        if (eql(str, "bright white")) return .{ .bright = .white };

        if (eql(str, "black")) return .{ .rgb = Rgb.black() };
        if (eql(str, "red")) return .{ .rgb = Rgb.red() };
        if (eql(str, "green")) return .{ .rgb = Rgb.green() };
        if (eql(str, "yellow")) return .{ .rgb = Rgb.yellow() };
        if (eql(str, "blue")) return .{ .rgb = Rgb.blue() };
        if (eql(str, "magenta")) return .{ .rgb = Rgb.magenta() };
        if (eql(str, "cyan")) return .{ .rgb = Rgb.cyan() };
        if (eql(str, "white")) return .{ .rgb = Rgb.white() };

        if (std.mem.startsWith(u8, str, "#")) {
            // hex
            if (str.len != 7) return error.UnrecognizedColor;
            const r = str[1..3];
            const g = str[3..5];
            const b = str[5..7];
            const parse = std.fmt.parseUnsigned;
            return .{ .rgb = Rgb{
                .r = parse(u8, r, 16) catch return error.UnrecognizedColor,
                .g = parse(u8, g, 16) catch return error.UnrecognizedColor,
                .b = parse(u8, b, 16) catch return error.UnrecognizedColor,
            } };
        }
        if (std.mem.startsWith(u8, str, "rgb")) {
            // rgb(r, g, b)
            // 7 is minimum for rgb(,,)
            if (str.len <= 7) return error.UnrecognizedColor;
            if (str[3] != '(' or str[str.len - 1] != ')') return error.UnrecognizedColor;
            // r, g, b without parentheses
            const rgb = str[4 .. str.len - 1];
            const r_start = std.mem.indexOfNone(u8, rgb, " ") orelse return error.UnrecognizedColor;
            const r_end = std.mem.indexOfAnyPos(u8, rgb, r_start, ", ") orelse return error.UnrecognizedColor;
            const g_start = std.mem.indexOfNonePos(u8, rgb, r_end + 1, ", ") orelse return error.UnrecognizedColor;
            const g_end = std.mem.indexOfAnyPos(u8, rgb, g_start, ", ") orelse return error.UnrecognizedColor;
            const b_start = std.mem.indexOfNonePos(u8, rgb, g_end + 1, ", ") orelse return error.UnrecognizedColor;
            const b_end = std.mem.indexOfAnyPos(u8, rgb, b_start + 1, " ") orelse rgb.len;

            const parse = std.fmt.parseUnsigned;
            return .{ .rgb = Rgb{
                .r = parse(u8, rgb[r_start..r_end], 0) catch return error.UnrecognizedColor,
                .g = parse(u8, rgb[g_start..g_end], 0) catch return error.UnrecognizedColor,
                .b = parse(u8, rgb[b_start..b_end], 0) catch return error.UnrecognizedColor,
            } };
        }

        return error.UnrecognizedColor;
    }
};

pub const ColorPair = struct {
    fg: Color,
    bg: Color,
};

// This function is intended to be used with strings knows at comptime.
// For everything else use Color.fromString directly.
pub fn color(comptime str: []const u8) Color {
    return comptime Color.fromString(str) catch @compileError("unrecognized color " ++ str);
}

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

test "simple color from string" {
    const expect = std.testing.expect;
    const eql = std.meta.eql;

    try expect(eql(color("bright black"), Color{ .bright = .black }));
    try expect(eql(color("bright red"), Color{ .bright = .red }));
    try expect(eql(color("bright green"), Color{ .bright = .green }));
    try expect(eql(color("bright yellow"), Color{ .bright = .yellow }));
    try expect(eql(color("bright blue"), Color{ .bright = .blue }));
    try expect(eql(color("bright magenta"), Color{ .bright = .magenta }));
    try expect(eql(color("bright cyan"), Color{ .bright = .cyan }));
    try expect(eql(color("bright white"), Color{ .bright = .white }));

    try expect(eql(color("dark black"), Color{ .dark = .black }));
    try expect(eql(color("dark red"), Color{ .dark = .red }));
    try expect(eql(color("dark green"), Color{ .dark = .green }));
    try expect(eql(color("dark yellow"), Color{ .dark = .yellow }));
    try expect(eql(color("dark blue"), Color{ .dark = .blue }));
    try expect(eql(color("dark magenta"), Color{ .dark = .magenta }));
    try expect(eql(color("dark cyan"), Color{ .dark = .cyan }));
    try expect(eql(color("dark white"), Color{ .dark = .white }));
}

test "rgb by name" {
    const expect = std.testing.expect;
    const eql = std.meta.eql;

    try expect(eql(color("black"), Color{ .rgb = Rgb.black() }));
    try expect(eql(color("red"), Color{ .rgb = Rgb.red() }));
    try expect(eql(color("green"), Color{ .rgb = Rgb.green() }));
    try expect(eql(color("yellow"), Color{ .rgb = Rgb.yellow() }));
    try expect(eql(color("blue"), Color{ .rgb = Rgb.blue() }));
    try expect(eql(color("magenta"), Color{ .rgb = Rgb.magenta() }));
    try expect(eql(color("cyan"), Color{ .rgb = Rgb.cyan() }));
    try expect(eql(color("white"), Color{ .rgb = Rgb.white() }));
}

test "rgb from hex string" {
    const expect = std.testing.expect;
    const eql = std.meta.eql;

    try expect(eql(color("#FF0000"), Color{ .rgb = .{ .r = 255, .g = 0, .b = 0 } }));
    try expect(eql(color("#00FF00"), Color{ .rgb = .{ .r = 0, .g = 255, .b = 0 } }));
    try expect(eql(color("#0000FF"), Color{ .rgb = .{ .r = 0, .g = 0, .b = 255 } }));

    try expect(eql(color("#ff0000"), Color{ .rgb = .{ .r = 255, .g = 0, .b = 0 } }));
    try expect(eql(color("#00ff00"), Color{ .rgb = .{ .r = 0, .g = 255, .b = 0 } }));
    try expect(eql(color("#0000ff"), Color{ .rgb = .{ .r = 0, .g = 0, .b = 255 } }));

    try expect(eql(color("#9520e6"), Color{ .rgb = .{ .r = 149, .g = 32, .b = 230 } }));
    try expect(eql(color("#d6f184"), Color{ .rgb = .{ .r = 214, .g = 241, .b = 132 } }));
    try expect(eql(color("#5ded68"), Color{ .rgb = .{ .r = 93, .g = 237, .b = 104 } }));

    try expect(eql(color("#9520E6"), Color{ .rgb = .{ .r = 149, .g = 32, .b = 230 } }));
    try expect(eql(color("#D6F184"), Color{ .rgb = .{ .r = 214, .g = 241, .b = 132 } }));
    try expect(eql(color("#5DED68"), Color{ .rgb = .{ .r = 93, .g = 237, .b = 104 } }));
}

test "rgb from rgb(r, g, b) string" {
    const expect = std.testing.expect;
    const eql = std.meta.eql;

    try expect(eql(color("rgb(0, 0, 0)"), Color{ .rgb = .{ .r = 0, .g = 0, .b = 0 } }));
    try expect(eql(color("rgb(255, 0, 0)"), Color{ .rgb = .{ .r = 255, .g = 0, .b = 0 } }));
    try expect(eql(color("rgb(0, 255, 0)"), Color{ .rgb = .{ .r = 0, .g = 255, .b = 0 } }));
    try expect(eql(color("rgb(0, 0, 255)"), Color{ .rgb = .{ .r = 0, .g = 0, .b = 255 } }));
    try expect(eql(color("rgb(255, 255, 255)"), Color{ .rgb = .{ .r = 255, .g = 255, .b = 255 } }));

    try expect(eql(color("rgb(149, 32, 230)"), Color{ .rgb = .{ .r = 149, .g = 32, .b = 230 } }));
    try expect(eql(color("rgb(214, 241, 132)"), Color{ .rgb = .{ .r = 214, .g = 241, .b = 132 } }));
    try expect(eql(color("rgb(93, 237, 104)"), Color{ .rgb = .{ .r = 93, .g = 237, .b = 104 } }));

    try expect(eql(color("rgb(0x95, 0x20, 0xe6)"), Color{ .rgb = .{ .r = 149, .g = 32, .b = 230 } }));
    try expect(eql(color("rgb(0xd6, 0xf1, 0x84)"), Color{ .rgb = .{ .r = 214, .g = 241, .b = 132 } }));
    try expect(eql(color("rgb(0x5d, 0xed, 0x68)"), Color{ .rgb = .{ .r = 93, .g = 237, .b = 104 } }));

    try expect(eql(color("rgb(255,   255,    255)"), Color{ .rgb = .{ .r = 255, .g = 255, .b = 255 } }));
    try expect(eql(color("rgb(255,255,255)"), Color{ .rgb = .{ .r = 255, .g = 255, .b = 255 } }));
    try expect(eql(color("rgb(255,255,255 )"), Color{ .rgb = .{ .r = 255, .g = 255, .b = 255 } }));
    try expect(eql(color("rgb( 255 , 255 , 255 )"), Color{ .rgb = .{ .r = 255, .g = 255, .b = 255 } }));
}
