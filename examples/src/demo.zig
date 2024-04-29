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

const CustomThemeState = struct {
    theme: usize = 0,

    border: tuile.Border = tuile.Border.all(),

    border_type: tuile.BorderType = .solid,

    tui: *tuile.Tuile,

    pub fn onThemeChange(ptr: ?*anyopaque, idx: usize, state: bool) void {
        var self: *CustomThemeState = @ptrCast(@alignCast(ptr.?));
        if (state) {
            self.theme = idx;
            self.updateTheme();
        }
    }

    pub fn onBorderChange(ptr: ?*anyopaque, idx: usize, state: bool) void {
        var self: *CustomThemeState = @ptrCast(@alignCast(ptr.?));
        switch (idx) {
            0 => self.border.top = state,
            1 => self.border.right = state,
            2 => self.border.bottom = state,
            3 => self.border.left = state,
            else => unreachable,
        }
        self.updateBorder();
    }

    pub fn onBorderTypeChange(ptr: ?*anyopaque, idx: usize, state: bool) void {
        var self: *CustomThemeState = @ptrCast(@alignCast(ptr.?));
        if (state) {
            switch (idx) {
                0 => self.border_type = .simple,
                1 => self.border_type = .solid,
                2 => self.border_type = .rounded,
                3 => self.border_type = .double,
                else => unreachable,
            }
            self.updateBorder();
        }
    }

    fn updateTheme(self: CustomThemeState) void {
        const theme = switch (self.theme) {
            0 => tuile.Theme.amber(),
            1 => tuile.Theme.lime(),
            2 => tuile.Theme.sky(),
            else => unreachable,
        };
        const themed = self.tui.findByIdTyped(tuile.Themed, "themed") orelse unreachable;
        themed.setTheme(theme);
    }

    fn updateBorder(self: CustomThemeState) void {
        const block = self.tui.findByIdTyped(tuile.Block, "borders") orelse unreachable;
        block.border = self.border;
        block.border_type = self.border_type;
    }
};

const UserInputState = struct {
    input: []const u8 = "",

    tui: *tuile.Tuile,

    pub fn onPress(ptr: ?*anyopaque) void {
        const self: *UserInputState = @ptrCast(@alignCast(ptr.?));
        if (self.input.len > 0) {
            const label = self.tui.findByIdTyped(tuile.Label, "user-input") orelse unreachable;
            label.setText(self.input) catch unreachable;
        }
    }

    pub fn inputChanged(ptr: ?*anyopaque, value: []const u8) void {
        const self: *UserInputState = @ptrCast(@alignCast(ptr.?));
        self.input = value;
    }
};

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

    var custom_theme_state = CustomThemeState{ .tui = &tui };

    var user_input_state = UserInputState{ .tui = &tui };

    const layout = tuile.vertical(
        .{ .layout = .{ .flex = 1 } },
        .{
            tuile.label(.{ .span = palette.view() }),
            tuile.label(.{ .span = styles.view() }),

            tuile.themed(
                .{ .id = "themed", .theme = tuile.Theme.amber() },
                tuile.block(
                    .{
                        .id = "borders",
                        .border = custom_theme_state.border,
                        .border_type = custom_theme_state.border_type,
                        .padding = .{ .top = 1, .bottom = 1 },
                    },
                    tuile.horizontal(.{}, .{
                        tuile.spacer(.{}),
                        tuile.vertical(.{}, .{
                            tuile.label(.{ .text = "Customizable themes:" }),
                            tuile.checkbox_group(
                                .{ .multiselect = false, .on_state_change = .{ .cb = @ptrCast(&CustomThemeState.onThemeChange), .payload = &custom_theme_state } },
                                .{
                                    tuile.checkbox(.{ .text = "Amber", .checked = true, .role = .radio }),
                                    tuile.checkbox(.{ .text = "Lime", .role = .radio }),
                                    tuile.checkbox(.{ .text = "Sky", .role = .radio }),
                                },
                            ),
                        }),
                        tuile.spacer(.{}),
                        tuile.vertical(.{}, .{
                            tuile.label(.{ .text = "Borders:" }),
                            tuile.horizontal(.{}, .{
                                tuile.checkbox_group(
                                    .{ .multiselect = true, .on_state_change = .{ .cb = @ptrCast(&CustomThemeState.onBorderChange), .payload = &custom_theme_state } },
                                    .{
                                        tuile.checkbox(.{ .text = "Top", .checked = custom_theme_state.border.top }),
                                        tuile.checkbox(.{ .text = "Right", .checked = custom_theme_state.border.right }),
                                        tuile.checkbox(.{ .text = "Bottom", .checked = custom_theme_state.border.bottom }),
                                        tuile.checkbox(.{ .text = "Left", .checked = custom_theme_state.border.left }),
                                    },
                                ),
                                tuile.spacer(.{ .layout = .{ .max_height = 3, .max_width = 3 } }),
                                tuile.checkbox_group(
                                    .{ .multiselect = false, .on_state_change = .{ .cb = @ptrCast(&CustomThemeState.onBorderTypeChange), .payload = &custom_theme_state } },
                                    .{
                                        tuile.checkbox(.{ .text = "Simple", .checked = (custom_theme_state.border_type == .simple), .role = .radio }),
                                        tuile.checkbox(.{ .text = "Solid", .checked = (custom_theme_state.border_type == .solid), .role = .radio }),
                                        tuile.checkbox(.{ .text = "Rounded", .checked = (custom_theme_state.border_type == .rounded), .role = .radio }),
                                        tuile.checkbox(.{ .text = "Double", .checked = (custom_theme_state.border_type == .double), .role = .radio }),
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
            tuile.label(.{ .text = "User inputs" }),
            tuile.block(
                .{ .layout = .{ .flex = 2, .max_height = 5 }, .border = tuile.Border.all() },
                tuile.label(.{ .id = "user-input", .text = "" }),
            ),
            tuile.horizontal(.{}, .{
                tuile.input(.{
                    .placeholder = "placeholder",
                    .layout = .{ .flex = 1 },
                    .on_value_changed = .{ .cb = UserInputState.inputChanged, .payload = &user_input_state },
                }),
                tuile.spacer(.{ .layout = .{ .max_width = 1, .max_height = 1 } }),
                tuile.button(.{ .text = "Submit", .on_press = .{ .cb = UserInputState.onPress, .payload = &user_input_state } }),
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
