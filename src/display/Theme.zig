const std = @import("std");
const colors = @import("colors.zig");
const Color = colors.Color;
const color = colors.color;

const Theme = @This();

text_primary: Color = color("#4F3422"),

text_secondary: Color = color("#AB6400"),

background: Color = color("#FEFDFB"),

interactive: Color = color("#FFF7C2"),

focused: Color = color("#FBE577"),

borders: Color = color("#E9C162"),

solid: Color = color("#E2A336"),

pub fn amber() Theme {
    return Theme{
        .text_primary = color("#4F3422"),
        .text_secondary = color("#AB6400"),
        .background = color("#FEFBE9"),
        .interactive = color("#FFF7C2"),
        .focused = color("#FBE577"),
        .borders = color("#E9C162"),
        .solid = color("#E2A336"),
    };
}

pub fn lime() Theme {
    return Theme{
        .text_primary = color("#37401C"),
        .text_secondary = color("#5C7C2F"),
        .background = color("#F8FAF3"),
        .interactive = color("#EEF6D6"),
        .focused = color("#D3E7A6"),
        .borders = color("#ABC978"),
        .solid = color("#8DB654"),
    };
}

pub fn sky() Theme {
    return Theme{
        .text_primary = color("#1D3E56"),
        .text_secondary = color("#00749E"),
        .background = color("#F1FAFD"),
        .interactive = color("#E1F6FD"),
        .focused = color("#BEE7F5"),
        .borders = color("#8DCAE3"),
        .solid = color("#60B3D7"),
    };
}
