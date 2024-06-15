const std = @import("std");
const tuile = @import("tuile.zig");
const internal = @import("internal.zig");

comptime {
    _ = @import("widgets/callbacks.zig");
    _ = @import("display/span.zig");
    _ = @import("display/colors.zig");
    _ = @import("text_clustering.zig");
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
            .{ .border = tuile.Border.all(), .border_type = .simple },
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
            .{ .border = tuile.Border.all(), .border_type = .rounded },
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
            .{ .border = tuile.Border.all(), .border_type = .simple },
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
            .{ .border = tuile.Border.all(), .border_type = .simple },
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
            .{ .border = tuile.Border.all(), .border_type = .simple, .layout = .{ .flex = 1 } },
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
            .{ .border = tuile.Border.all(), .border_type = .simple, .layout = .{ .flex = 1 } },
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
            .{ .border = tuile.Border.all(), .border_type = .simple, .layout = .{ .flex = 1 } },
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
            .{ .border = tuile.Border.all(), .border_type = .simple, .padding = .{
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
        "  [x] Checkbox  \n" ++
        "                \n";

    try renderAndCompare(
        .{ .x = 16, .y = 2 },
        tuile.checkbox(.{ .text = "Checkbox", .checked = true }),
        expected,
    );
}

test "checkbox group" {
    const expected =
        "  [x] Option 1  \n" ++
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

test "vertical stack" {
    const expected =
        "       L1       \n" ++
        "       L2       \n" ++
        "       L3       \n" ++
        "                \n";

    try renderAndCompare(
        .{ .x = 16, .y = 4 },
        tuile.vertical(.{}, .{
            tuile.label(.{ .text = "L1" }),
            tuile.label(.{ .text = "L2" }),
            tuile.label(.{ .text = "L3" }),
        }),
        expected,
    );
}

test "horizontal stack" {
    const expected =
        "     L1L2L3     \n" ++
        "                \n" ++
        "                \n";

    try renderAndCompare(
        .{ .x = 16, .y = 3 },
        tuile.horizontal(.{}, .{
            tuile.label(.{ .text = "L1" }),
            tuile.label(.{ .text = "L2" }),
            tuile.label(.{ .text = "L3" }),
        }),
        expected,
    );
}

test "horizontal flex stack" {
    const expected =
        "                \n" ++
        "     L1L2L3     \n" ++
        "                \n";

    try renderAndCompare(
        .{ .x = 16, .y = 3 },
        tuile.horizontal(.{ .layout = .{ .flex = 1 } }, .{
            tuile.label(.{ .text = "L1" }),
            tuile.label(.{ .text = "L2" }),
            tuile.label(.{ .text = "L3" }),
        }),
        expected,
    );
}

test "vertical stack with flex elements" {
    const expected =
        "┌──────────────────┐\n" ++
        "│                  │\n" ++
        "│     In block     │\n" ++
        "│                  │\n" ++
        "│                  │\n" ++
        "└──────────────────┘\n" ++
        "       First        \n" ++
        "       Second       \n";

    try renderAndCompare(
        .{ .x = 20, .y = 8 },
        tuile.vertical(.{ .layout = .{ .flex = 1 } }, .{
            tuile.block(
                .{ .layout = .{ .flex = 1 }, .border = tuile.Border.all() },
                tuile.label(.{ .text = "In block" }),
            ),
            tuile.label(.{ .text = "First" }),
            tuile.label(.{ .text = "Second" }),
        }),
        expected,
    );
}

test "space for flex elements is distributed according to their weight" {
    const expected =
        "┌──────────────────┐\n" ++
        "│     flex = 1     │\n" ++
        "└──────────────────┘\n" ++
        "┌──────────────────┐\n" ++
        "│                  │\n" ++
        "│     flex = 2     │\n" ++
        "│                  │\n" ++
        "│                  │\n" ++
        "└──────────────────┘\n";

    try renderAndCompare(
        .{ .x = 20, .y = 9 },
        tuile.vertical(.{ .layout = .{ .flex = 1 } }, .{
            tuile.block(
                .{ .layout = .{ .flex = 1 }, .border = tuile.Border.all() },
                tuile.label(.{ .text = "flex = 1" }),
            ),
            tuile.block(
                .{ .layout = .{ .flex = 2 }, .border = tuile.Border.all() },
                tuile.label(.{ .text = "flex = 2" }),
            ),
        }),
        expected,
    );
}

test "spacers between elements" {
    const expected =
        "    ┌───────┐        ┌───────┐    \n" ++
        "    │       │        │       │    \n" ++
        "    │       │        │       │    \n" ++
        "    │       │        │       │    \n" ++
        "    │Block 1│        │Block 2│    \n" ++
        "    │       │        │       │    \n" ++
        "    │       │        │       │    \n" ++
        "    │       │        │       │    \n" ++
        "    └───────┘        └───────┘    \n";

    try renderAndCompare(
        .{ .x = 34, .y = 9 },
        tuile.horizontal(.{ .layout = .{ .flex = 1 } }, .{
            tuile.spacer(.{ .layout = .{ .flex = 1 } }),
            tuile.block(
                .{ .border = tuile.Border.all() },
                tuile.label(.{ .text = "Block 1" }),
            ),
            tuile.spacer(.{ .layout = .{ .flex = 2 } }),
            tuile.block(
                .{ .border = tuile.Border.all() },
                tuile.label(.{ .text = "Block 2" }),
            ),
            tuile.spacer(.{ .layout = .{ .flex = 1 } }),
        }),
        expected,
    );
}

test "spacer inside block" {
    const expected =
        "┌────────────────────────────────┐\n" ++
        "│                                │\n" ++
        "│                                │\n" ++
        "│                                │\n" ++
        "│                                │\n" ++
        "│                                │\n" ++
        "│                                │\n" ++
        "│                                │\n" ++
        "└────────────────────────────────┘\n";

    try renderAndCompare(
        .{ .x = 34, .y = 9 },
        tuile.horizontal(.{ .layout = .{ .flex = 1 } }, .{
            tuile.block(
                .{ .border = tuile.Border.all() },
                tuile.spacer(.{ .layout = .{ .flex = 1 } }),
            ),
        }),
        expected,
    );
}

test "spacer with fixed size" {
    const expected =
        "              ┌────┐              \n" ++
        "              │    │              \n" ++
        "              │    │              \n" ++
        "              │    │              \n" ++
        "              │    │              \n" ++
        "              │    │              \n" ++
        "              │    │              \n" ++
        "              │    │              \n" ++
        "              └────┘              \n";

    try renderAndCompare(
        .{ .x = 34, .y = 9 },
        tuile.horizontal(.{ .layout = .{ .flex = 1 } }, .{
            tuile.block(
                .{ .border = tuile.Border.all() },
                // Spacer only works in the direction of the layout.
                // In the cross direction it occupies all the space.
                // Use block with fit_content = true if you want it to be specific size.
                tuile.spacer(.{ .layout = .{ .max_width = 4, .max_height = 4 } }),
            ),
        }),
        expected,
    );
}

test "block fit content" {
    const expected =
        "                                  \n" ++
        "              ┌────┐              \n" ++
        "              │    │              \n" ++
        "              │    │              \n" ++
        "              │    │              \n" ++
        "              │    │              \n" ++
        "              └────┘              \n" ++
        "                                  \n" ++
        "                                  \n";

    try renderAndCompare(
        .{ .x = 34, .y = 9 },
        tuile.horizontal(.{ .layout = .{ .flex = 1 } }, .{
            tuile.block(
                .{ .border = tuile.Border.all(), .fit_content = true },
                tuile.spacer(.{ .layout = .{ .max_width = 4, .max_height = 4 } }),
            ),
        }),
        expected,
    );
}
