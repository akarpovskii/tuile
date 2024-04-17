pub const Color = enum(u4) {
    black,
    red,
    green,
    yellow,
    blue,
    magenta,
    cyan,
    gray,
    dark_gray,
    light_red,
    light_green,
    light_yellow,
    light_blue,
    light_magenta,
    light_cyan,
    white,
};

pub const ColorPair = packed struct(u8) {
    fg: Color,
    bg: Color,
};
