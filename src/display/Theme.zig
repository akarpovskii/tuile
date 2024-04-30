const std = @import("std");
const colors = @import("colors.zig");
const Color = colors.Color;
const color = colors.color;

const Theme = @This();

/// Used by widgets to print main text and foreground
text_primary: Color,

/// Used by widgets to print alternative or not unimportant text
text_secondary: Color,

/// The primary background of the application
background_primary: Color,

/// Widgets may use this color to stand out from the main background
background_secondary: Color,

/// Used by all interactive components
interactive: Color,

/// Color of the focused interactive element
focused: Color,

/// Borders of the Block widget
borders: Color,

/// A solid color that widgets may use to highlight something.
/// For example, Input uses it for the color of the cursor.
solid: Color,

pub fn amber() Theme {
    return Theme{
        .text_primary = color("#4F3422"),
        .text_secondary = color("#AB6400"),
        .background_primary = color("#FEFDFB"),
        .background_secondary = color("#FEFBE9"),
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
        .background_primary = color("#FCFDFA"),
        .background_secondary = color("#D7FFD7"),
        .interactive = color("#D7FFAF"),
        .focused = color("#D3E7A6"),
        .borders = color("#ABC978"),
        .solid = color("#8DB654"),
    };
}

pub fn sky() Theme {
    return Theme{
        .text_primary = color("#1D3E56"),
        .text_secondary = color("#00749E"),
        .background_primary = color("#F9FEFF"),
        .background_secondary = color("#D7FFFF"),
        .interactive = color("#AFFFFF"),
        .focused = color("#BEE7F5"),
        .borders = color("#8DCAE3"),
        .solid = color("#60B3D7"),
    };
}
