const std = @import("std");
const tuile = @import("tuile");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const tuile_allocator = gpa.allocator();

fn generatePalette() !tuile.Span {
    var span = tuile.Span.init(tuile_allocator);
    for (1..257) |i| {
        const rgb = tuile.Palette256.lookup_table[i - 1];
        const color = tuile.Color{ .rgb = .{ .r = rgb[0], .g = rgb[1], .b = rgb[2] } };
        if (i <= 16) {
            if (i == 1) {
                try span.appendPlain("    ");
            }
            try span.append(.{ .text = "    ", .style = .{ .fg = color, .bg = color } });
            if (i == 16) {
                try span.appendPlain("    \n");
            }
        } else if (i <= 232) {
            try span.append(.{ .text = "  ", .style = .{ .fg = color, .bg = color } });
            if ((i - 16) % 36 == 0) {
                try span.appendPlain("\n");
            }
        } else {
            try span.append(.{ .text = "   ", .style = .{ .fg = color, .bg = color } });
        }
    }
    return span;
}

fn generateStyles() !tuile.Span {
    var span = tuile.Span.init(tuile_allocator);
    try span.appendPlain("Styles: ");
    try span.append(.{ .text = "bold", .style = .{ .add_effect = .{ .bold = true } } });
    try span.appendPlain(", ");
    try span.append(.{ .text = "italic", .style = .{ .add_effect = .{ .italic = true } } });
    try span.appendPlain(", ");
    try span.append(.{ .text = "underline", .style = .{ .add_effect = .{ .underline = true } } });
    try span.appendPlain(", ");
    try span.append(.{ .text = "dim", .style = .{ .add_effect = .{ .dim = true } } });
    try span.appendPlain(", ");
    try span.append(.{ .text = "blink", .style = .{ .add_effect = .{ .blink = true } } });
    try span.appendPlain(", ");
    try span.append(.{ .text = "reverse", .style = .{ .add_effect = .{ .reverse = true } } });
    try span.appendPlain(", ");
    try span.append(.{ .text = "highlight", .style = .{ .add_effect = .{ .highlight = true } } });
    return span;
}

fn generateMultilineSpan() !tuile.Span {
    var span = tuile.Span.init(tuile_allocator);
    try span.append(.{ .style = .{ .fg = tuile.color("red") }, .text = "Lorem ipsum dolor sit amet, consectetur adipiscing elit.\n" });
    try span.append(.{ .style = .{ .fg = tuile.color("green") }, .text = "Nullam aliquam mollis sapien, eget pretium dui.\n" });
    try span.append(.{ .style = .{ .fg = tuile.color("blue") }, .text = "Nam lobortis turpis ac nunc vehicula cursus in vitae leo.\n" });
    try span.append(.{ .style = .{ .fg = tuile.color("magenta") }, .text = "Donec malesuada accumsan tortor at porta." });
    return span;
}

pub fn main() !void {
    defer _ = gpa.deinit();

    var tui = try tuile.Tuile.init(.{});
    defer tui.deinit();

    var palette = try generatePalette();
    defer palette.deinit();

    var styles = try generateStyles();
    defer styles.deinit();

    var multiline_span = try generateMultilineSpan();
    defer multiline_span.deinit();

    const layout = tuile.vertical(
        .{ .layout = .{ .flex = 1 } },
        .{
            tuile.label(.{ .span = palette.view() }), tuile.label(.{ .span = styles.view() }),
            tuile.themed(
                .{ .theme = .{
                    .background = tuile.color("blue"),
                    .foreground = tuile.color("white"),
                } },
                tuile.block(
                    .{
                        .border = tuile.border.Border.all(),
                        .padding = .{ .top = 1, .bottom = 1 },
                    },
                    tuile.horizontal(.{}, .{
                        tuile.spacer(.{}),
                        tuile.vertical(.{}, .{
                            tuile.label(.{ .text = "Customizable themes:" }),
                            tuile.checkbox_group(
                                .{ .multiselect = false },
                                .{
                                    tuile.checkbox(.{ .text = "Theme 1", .checked = true, .role = .radio }),
                                    tuile.checkbox(.{ .text = "Theme 2", .role = .radio }),
                                    tuile.checkbox(.{ .text = "Theme 3", .role = .radio }),
                                },
                            ),
                        }),
                        tuile.spacer(.{}),
                        tuile.vertical(.{}, .{
                            tuile.label(.{ .text = "Borders:" }),
                            tuile.horizontal(.{}, .{
                                tuile.checkbox_group(
                                    .{ .multiselect = true },
                                    .{
                                        tuile.checkbox(.{ .text = "Top", .checked = true }),
                                        tuile.checkbox(.{ .text = "Right", .checked = true }),
                                        tuile.checkbox(.{ .text = "Bottom", .checked = true }),
                                        tuile.checkbox(.{ .text = "Left", .checked = true }),
                                    },
                                ),
                                tuile.spacer(.{ .layout = .{ .max_height = 3, .max_width = 3 } }),
                                tuile.checkbox_group(
                                    .{ .multiselect = false },
                                    .{
                                        tuile.checkbox(.{ .text = "Simple" }),
                                        tuile.checkbox(.{ .text = "Solid", .checked = true }),
                                        tuile.checkbox(.{ .text = "Round" }),
                                        tuile.checkbox(.{ .text = "Double" }),
                                    },
                                ),
                            }),
                        }),
                        tuile.spacer(.{}),
                    }),
                ),
            ),
            tuile.block(
                .{
                    .border = tuile.border.Border.all(),
                    .border_type = .rounded,
                    .padding = .{ .top = 1, .bottom = 1, .left = 1, .right = 1 },
                },
                tuile.vertical(.{}, .{
                    tuile.label(.{ .text = "Multiline text:" }),
                    tuile.label(.{ .span = multiline_span.view() }),
                }),
            ),

            tuile.label(.{ .text = "Alignment" }),
            tuile.horizontal(.{}, .{
                tuile.block(
                    .{ .layout = .{ .flex = 1, .max_height = 6 }, .border = tuile.Border.all() },
                    tuile.label(.{ .text = "TL", .layout = .{ .alignment = tuile.Align.topLeft() } }),
                ),
                tuile.block(
                    .{ .layout = .{ .flex = 1, .max_height = 6 }, .border = tuile.Border.all() },
                    tuile.label(.{ .text = "TR", .layout = .{ .alignment = tuile.Align.topRight() } }),
                ),
                tuile.block(
                    .{ .layout = .{ .flex = 1, .max_height = 6 }, .border = tuile.Border.all() },
                    tuile.label(.{ .text = "BL", .layout = .{ .alignment = tuile.Align.bottomLeft() } }),
                ),
                tuile.block(
                    .{ .layout = .{ .flex = 1, .max_height = 6 }, .border = tuile.Border.all() },
                    tuile.label(.{ .text = "BR", .layout = .{ .alignment = tuile.Align.bottomRight() } }),
                ),
            }),
            tuile.block(
                .{ .layout = .{ .flex = 2, .max_height = 6 }, .border = tuile.Border.all() },
                tuile.label(.{ .text = "User inputs:", .layout = .{ .alignment = tuile.Align.topLeft() } }),
            ),
            tuile.horizontal(.{}, .{
                tuile.input(.{ .placeholder = "placeholder", .layout = .{ .flex = 1 } }),
                tuile.button(.{ .text = "Submit" }),
            }),
            tuile.spacer(.{}),
            tuile.label(.{ .text = "Tab/Shift+Tab to move between elements, Space to interract" }),
        },
    );

    try tui.add(layout);

    try tui.run();
}

fn handlePress(label: []const u8) void {
    std.debug.print("\tPressed {s}", .{label});
}
