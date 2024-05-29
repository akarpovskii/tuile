const std = @import("std");
const tuile = @import("tuile");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const tuile_allocator = gpa.allocator();

const UserInputState = struct {
    tui: *tuile.Tuile,

    pub fn inputChanged(self_opt: ?*UserInputState, value: []const u8) void {
        const self = self_opt.?;
        if (value.len > 0) {
            const label = self.tui.findByIdTyped(tuile.Label, "unicode-table") orelse unreachable;
            const start = std.fmt.parseInt(u21, value, 16) catch {
                label.setText("Invalid hex code") catch unreachable;
                return;
            };

            const txt = generateUnicodeTable(start);
            label.setText(txt) catch unreachable;
            tuile_allocator.free(txt);
        }
    }

    fn generateUnicodeTable(start: u21) []const u8 {
        var string = std.ArrayListUnmanaged(u8){};
        const w = 32;
        const h = 32;
        for (0..h) |y| {
            for (0..w) |x| {
                const character: u21 = @intCast(start + y * w + x);
                var cp = std.mem.zeroes([4]u8);
                const len = std.unicode.utf8Encode(character, &cp) catch @panic("Incorrect unicode");
                string.appendSlice(tuile_allocator, cp[0..len]) catch @panic("OOM");
            }
            string.append(tuile_allocator, '\n') catch @panic("OOM");
        }
        return string.toOwnedSlice(tuile_allocator) catch @panic("OOM");
    }
};

pub fn main() !void {
    var tui = try tuile.Tuile.init(.{});
    defer tui.deinit();

    var input_state = UserInputState{ .tui = &tui };

    const layout = tuile.vertical(
        .{ .layout = .{ .flex = 1 } },
        .{
            tuile.block(
                .{ .border = tuile.border.Border.all(), .layout = .{ .flex = 1 } },
                tuile.label(.{ .id = "unicode-table", .text = "" }),
            ),

            tuile.horizontal(
                .{},
                .{
                    tuile.label(.{ .text = "Starting unicode value: U+" }), tuile.input(.{
                        .id = "user-input",
                        .layout = .{ .flex = 1 },
                        .on_value_changed = .{
                            .cb = @ptrCast(&UserInputState.inputChanged),
                            .payload = &input_state,
                        },
                    }),
                },
            ),
        },
    );

    try tui.add(layout);

    const input = tui.findByIdTyped(tuile.Input, "user-input") orelse unreachable;
    try input.setValue("1F300");
    UserInputState.inputChanged(&input_state, "1F300");

    try tui.run();
}
