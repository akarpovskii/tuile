const std = @import("std");
const tuile = @import("tuile.zig");
const internal = @import("internal.zig");

comptime {
    _ = @import("widgets/ChangeNotifier.zig");
    _ = @import("widgets/callbacks.zig");
    _ = @import("display/span.zig");
    _ = @import("display/colors.zig");
}

test {
    std.testing.refAllDecls(@This());
}

fn renderWidget(window_size: tuile.Vec2, layout: anytype) !std.ArrayList(u8) {
    const backend = try tuile.backends.Testing.create(window_size);

    var tui = try tuile.Tuile.init(.{ .backend = backend.backend() });
    defer tui.deinit();
    try tui.add(layout);
    try tui.step();

    var content = std.ArrayList(u8).init(internal.allocator);
    errdefer content.deinit();
    try backend.write(content.writer());
    return content;
}

fn renderAndCompare(window_size: tuile.Vec2, layout: anytype, expected: []const u8) !void {
    const content = try renderWidget(window_size, layout);
    defer content.deinit();
    const result = std.testing.expect(std.mem.eql(u8, content.items, expected));
    if (std.meta.isError(result)) {
        std.log.err("\nExpected:\n{s}\nActual:\n{s}", .{ expected, content.items });
    }
    return result;
}

test "label" {
    const expected =
        "     Label text     \n" ++
        "                    \n" ++
        "                    \n";

    try renderAndCompare(
        .{ .x = 20, .y = 3 },
        tuile.label(.{ .text = "Label text" }),
        expected,
    );
}

test "label align left" {
    const expected =
        "Label text          \n" ++
        "                    \n" ++
        "                    \n";

    try renderAndCompare(
        .{ .x = 20, .y = 3 },
        tuile.label(.{ .text = "Label text", .layout = .{ .alignment = tuile.LayoutProperties.Align.topLeft() } }),
        expected,
    );
}

test "label align right" {
    const expected =
        "          Label text\n" ++
        "                    \n" ++
        "                    \n";

    try renderAndCompare(
        .{ .x = 20, .y = 3 },
        tuile.label(.{ .text = "Label text", .layout = .{ .alignment = tuile.LayoutProperties.Align.topRight() } }),
        expected,
    );
}

test "label inside flex block" {
    const expected =
        "                    \n" ++
        "     Label text     \n" ++
        "                    \n";

    try renderAndCompare(
        .{ .x = 20, .y = 3 },
        tuile.block(
            .{ .layout = .{ .flex = 1 } },
            tuile.label(.{ .text = "Label text" }),
        ),
        expected,
    );
}

test "block with simple borders" {
    const expected =
        "+------------------+\n" ++
        "|    Label text    |\n" ++
        "+------------------+\n";

    try renderAndCompare(
        .{ .x = 20, .y = 3 },
        tuile.block(
            .{ .border = tuile.border.Border.all(), .border_type = .simple },
            tuile.label(.{ .text = "Label text" }),
        ),
        expected,
    );
}

test "block with rounded borders" {
    const expected =
        "╭──────────────────╮\n" ++
        "│    Label text    │\n" ++
        "╰──────────────────╯\n";

    try renderAndCompare(
        .{ .x = 20, .y = 3 },
        tuile.block(
            .{ .border = tuile.border.Border.all(), .border_type = .rounded },
            tuile.label(.{ .text = "Label text" }),
        ),
        expected,
    );
}

test "align left inside block" {
    const expected =
        "+------------------+\n" ++
        "|Label text        |\n" ++
        "+------------------+\n";

    try renderAndCompare(
        .{ .x = 20, .y = 3 },
        tuile.block(
            .{ .border = tuile.border.Border.all(), .border_type = .simple },
            tuile.label(.{ .text = "Label text", .layout = .{ .alignment = tuile.LayoutProperties.Align.topLeft() } }),
        ),
        expected,
    );
}

test "align right inside block" {
    const expected =
        "+------------------+\n" ++
        "|        Label text|\n" ++
        "+------------------+\n";

    try renderAndCompare(
        .{ .x = 20, .y = 3 },
        tuile.block(
            .{ .border = tuile.border.Border.all(), .border_type = .simple },
            tuile.label(.{ .text = "Label text", .layout = .{ .alignment = tuile.LayoutProperties.Align.topRight() } }),
        ),
        expected,
    );
}

test "align top inside block" {
    const expected =
        "+------------------+\n" ++
        "|    Label text    |\n" ++
        "|                  |\n" ++
        "|                  |\n" ++
        "+------------------+\n";

    try renderAndCompare(
        .{ .x = 20, .y = 5 },
        tuile.block(
            .{ .border = tuile.border.Border.all(), .border_type = .simple, .layout = .{ .flex = 1 } },
            tuile.label(.{ .text = "Label text", .layout = .{ .alignment = tuile.LayoutProperties.Align.topCenter() } }),
        ),
        expected,
    );
}

test "align bottom inside block" {
    const expected =
        "+------------------+\n" ++
        "|                  |\n" ++
        "|                  |\n" ++
        "|    Label text    |\n" ++
        "+------------------+\n";

    try renderAndCompare(
        .{ .x = 20, .y = 5 },
        tuile.block(
            .{ .border = tuile.border.Border.all(), .border_type = .simple, .layout = .{ .flex = 1 } },
            tuile.label(.{ .text = "Label text", .layout = .{ .alignment = tuile.LayoutProperties.Align.bottomCenter() } }),
        ),
        expected,
    );
}

test "align bottom left inside block" {
    const expected =
        "+------------------+\n" ++
        "|                  |\n" ++
        "|                  |\n" ++
        "|Label text        |\n" ++
        "+------------------+\n";

    try renderAndCompare(
        .{ .x = 20, .y = 5 },
        tuile.block(
            .{ .border = tuile.border.Border.all(), .border_type = .simple, .layout = .{ .flex = 1 } },
            tuile.label(.{ .text = "Label text", .layout = .{ .alignment = tuile.LayoutProperties.Align.bottomLeft() } }),
        ),
        expected,
    );
}

test "block padding" {
    const expected =
        "+------------------+\n" ++
        "|                  |\n" ++
        "|    Label text    |\n" ++
        "|                  |\n" ++
        "|                  |\n" ++
        "+------------------+\n" ++
        "                    \n";

    try renderAndCompare(
        .{ .x = 20, .y = 7 },
        tuile.block(
            .{ .border = tuile.border.Border.all(), .border_type = .simple, .padding = .{
                .top = 1,
                .bottom = 2,
                .left = 1,
                .right = 1,
            } },
            tuile.label(.{ .text = "Label text" }),
        ),
        expected,
    );
}

test "button" {
    const expected =
        "    [Button]    \n" ++
        "                \n";

    try renderAndCompare(
        .{ .x = 16, .y = 2 },
        tuile.button(.{ .text = "Button" }),
        expected,
    );
}

test "checkbox" {
    const expected =
        "  [ ] Checkbox  \n" ++
        "                \n";

    try renderAndCompare(
        .{ .x = 16, .y = 2 },
        tuile.checkbox(.{ .text = "Checkbox" }),
        expected,
    );
}

test "checked checkbox" {
    const expected =
        "  [*] Checkbox  \n" ++
        "                \n";

    try renderAndCompare(
        .{ .x = 16, .y = 2 },
        tuile.checkbox(.{ .text = "Checkbox", .checked = true }),
        expected,
    );
}

test "checkbox group" {
    const expected =
        "  [*] Option 1  \n" ++
        "  [ ] Option 2  \n" ++
        "  [ ] Option 3  \n" ++
        "                \n";

    try renderAndCompare(
        .{ .x = 16, .y = 4 },
        tuile.checkbox_group(.{}, .{
            tuile.checkbox(.{ .text = "Option 1", .checked = true }),
            tuile.checkbox(.{ .text = "Option 2", .checked = false }),
            tuile.checkbox(.{ .text = "Option 3", .checked = false }),
        }),
        expected,
    );
}

test "input" {
    const expected =
        "  placeholder   \n" ++
        "                \n";

    try renderAndCompare(
        .{ .x = 16, .y = 2 },
        tuile.input(.{ .placeholder = "placeholder" }),
        expected,
    );
}
