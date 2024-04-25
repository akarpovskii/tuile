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

    change_notifier: tuile.ChangeNotifier = tuile.ChangeNotifier.init(),
    pub usingnamespace tuile.ChangeNotifier.Mixin(@This(), .change_notifier);

    pub fn onThemeChange(ptr: ?*anyopaque, idx: usize, state: bool) void {
        var self: *CustomThemeState = @ptrCast(@alignCast(ptr.?));
        if (state) {
            self.theme = idx;
            self.notifyListeners();
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
        self.notifyListeners();
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
            self.notifyListeners();
        }
    }
};

const CustomThemeBlock = struct {
    pub fn build(_: *CustomThemeBlock, context: *tuile.StatefulWidget.BuildContext) !tuile.Widget {
        const state: *CustomThemeState = try context.watch(CustomThemeState);
        const layout = try tuile.themed(
            .{ .theme = switch (state.theme) {
                0 => tuile.Theme.amber(),
                1 => tuile.Theme.lime(),
                2 => tuile.Theme.sky(),
                else => unreachable,
            } },
            tuile.block(
                .{
                    .border = state.border,
                    .border_type = state.border_type,
                    .padding = .{ .top = 1, .bottom = 1 },
                },
                tuile.horizontal(.{}, .{
                    tuile.spacer(.{}),
                    tuile.vertical(.{}, .{
                        tuile.label(.{ .text = "Customizable themes:" }),
                        tuile.checkbox_group(
                            .{ .multiselect = false, .on_state_change = .{ .cb = CustomThemeState.onThemeChange, .payload = state } },
                            .{
                                tuile.checkbox(.{ .text = "Amber", .checked = (state.theme == 0), .role = .radio }),
                                tuile.checkbox(.{ .text = "Lime", .checked = (state.theme == 1), .role = .radio }),
                                tuile.checkbox(.{ .text = "Sky", .checked = (state.theme == 2), .role = .radio }),
                            },
                        ),
                    }),
                    tuile.spacer(.{}),
                    tuile.vertical(.{}, .{
                        tuile.label(.{ .text = "Borders:" }),
                        tuile.horizontal(.{}, .{
                            tuile.checkbox_group(
                                .{ .multiselect = true, .on_state_change = .{ .cb = CustomThemeState.onBorderChange, .payload = state } },
                                .{
                                    tuile.checkbox(.{ .text = "Top", .checked = state.border.top }),
                                    tuile.checkbox(.{ .text = "Right", .checked = state.border.right }),
                                    tuile.checkbox(.{ .text = "Bottom", .checked = state.border.bottom }),
                                    tuile.checkbox(.{ .text = "Left", .checked = state.border.left }),
                                },
                            ),
                            tuile.spacer(.{ .layout = .{ .max_height = 3, .max_width = 3 } }),
                            tuile.checkbox_group(
                                .{ .multiselect = false, .on_state_change = .{ .cb = CustomThemeState.onBorderTypeChange, .payload = state } },
                                .{
                                    tuile.checkbox(.{ .text = "Simple", .checked = (state.border_type == .simple), .role = .radio }),
                                    tuile.checkbox(.{ .text = "Solid", .checked = (state.border_type == .solid), .role = .radio }),
                                    tuile.checkbox(.{ .text = "Rounded", .checked = (state.border_type == .rounded), .role = .radio }),
                                    tuile.checkbox(.{ .text = "Double", .checked = (state.border_type == .double), .role = .radio }),
                                },
                            ),
                        }),
                    }),
                    tuile.spacer(.{}),
                }),
            ),
        );
        return layout.widget();
    }
};

const UserInputState = struct {
    input: []const u8 = "",

    change_notifier: tuile.ChangeNotifier = tuile.ChangeNotifier.init(),
    pub usingnamespace tuile.ChangeNotifier.Mixin(@This(), .change_notifier);

    pub fn onPress(ptr: ?*anyopaque) void {
        const self: *UserInputState = @ptrCast(@alignCast(ptr.?));
        if (self.input.len > 0) {
            self.notifyListeners();
        }
    }

    pub fn inputChanged(ptr: ?*anyopaque, value: []const u8) void {
        const self: *UserInputState = @ptrCast(@alignCast(ptr.?));
        self.input = value;
    }
};

const UserInputView = struct {
    pub fn build(_: *UserInputView, context: *tuile.StatefulWidget.BuildContext) !tuile.Widget {
        const state: *UserInputState = try context.watch(UserInputState);
        return (try tuile.label(.{ .text = state.input })).widget();
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

    var custom_theme_block = CustomThemeBlock{};
    var custom_theme_state = CustomThemeState{};
    defer custom_theme_state.change_notifier.deinit();

    var user_input_view = UserInputView{};
    var user_input_state = UserInputState{};
    defer user_input_state.change_notifier.deinit();

    const layout = tuile.vertical(
        .{ .layout = .{ .flex = 1 } },
        .{
            tuile.label(.{ .span = palette.view() }),
            tuile.label(.{ .span = styles.view() }),
            tuile.stateful(&custom_theme_block, &custom_theme_state),
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
                tuile.stateful(&user_input_view, &user_input_state),
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
