const std = @import("std");
const tuile = @import("tuile");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const tuile_allocator = gpa.allocator();

const UnicodeTable = struct {
    tui: *tuile.Tuile,

    pub fn inputChanged(self_opt: ?*UnicodeTable, value: []const u8) void {
        const self = self_opt.?;
        if (value.len > 0) {
            const label = self.tui.findByIdTyped(tuile.Label, "unicode-table") orelse unreachable;
            const start = std.fmt.parseInt(u21, value, 16) catch {
                label.setText("Invalid hex code") catch unreachable;
                return;
            };

            const txt = generateUnicodeTable(start);
            defer tuile_allocator.free(txt);
            label.setText(txt) catch unreachable;
        }
    }

    fn generateUnicodeTable(start: u21) []const u8 {
        var string = std.ArrayListUnmanaged(u8){};
        errdefer string.deinit(tuile_allocator);
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

const UnicodeBytes = struct {
    tui: *tuile.Tuile,

    pub fn inputChanged(self_opt: ?*UnicodeBytes, value: []const u8) void {
        const self = self_opt.?;
        if (value.len > 0) {
            const label = self.tui.findByIdTyped(tuile.Label, "unicode-bytes") orelse unreachable;

            var text = std.ArrayListUnmanaged(u8){};
            defer text.deinit(tuile_allocator);

            var iter = std.mem.tokenizeScalar(u8, value, ' ');
            while (iter.next()) |byte| {
                const character = std.fmt.parseInt(u8, byte, 0) catch {
                    label.setText("Invalid hex code") catch unreachable;
                    return;
                };
                text.append(tuile_allocator, character) catch @panic("OOM");
            }

            if (std.unicode.utf8ValidateSlice(text.items)) {
                label.setText(text.items) catch unreachable;
            } else {
                label.setText("Invalid unicode sequence") catch unreachable;
            }
        }
    }
};

pub fn main() !void {
    var tui = try tuile.Tuile.init(.{});
    defer tui.deinit();

    var unicode_table = UnicodeTable{ .tui = &tui };
    var unicode_bytes = UnicodeBytes{ .tui = &tui };

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
                    tuile.label(.{ .text = "Starting unicode value: U+" }),
                    tuile.input(.{
                        .id = "start-input",
                        .layout = .{ .flex = 1 },
                        .on_value_changed = .{
                            .cb = @ptrCast(&UnicodeTable.inputChanged),
                            .payload = &unicode_table,
                        },
                    }),
                },
            ),

            tuile.block(
                .{ .border = tuile.border.Border.all(), .layout = .{ .flex = 0 } },
                tuile.label(.{ .id = "unicode-bytes", .text = "" }),
            ),

            tuile.horizontal(
                .{},
                .{
                    tuile.label(.{ .text = "Unicode bytes (hex): " }),
                    tuile.input(.{
                        .id = "bytes-input",
                        .layout = .{ .flex = 1 },
                        .on_value_changed = .{
                            .cb = @ptrCast(&UnicodeBytes.inputChanged),
                            .payload = &unicode_bytes,
                        },
                    }),
                },
            ),
        },
    );

    try tui.add(layout);

    {
        const input = tui.findByIdTyped(tuile.Input, "start-input") orelse unreachable;
        try input.setValue("1F300");
        UnicodeTable.inputChanged(&unicode_table, "1F300");
    }

    {
        const input = tui.findByIdTyped(tuile.Input, "bytes-input") orelse unreachable;
        try input.setValue("0xF0 0x9F 0x91 0x8D 0xF0 0x9F 0x8F 0xBD");
        UnicodeBytes.inputChanged(&unicode_bytes, "0xF0 0x9F 0x91 0x8D 0xF0 0x9F 0x8F 0xBD");
    }

    try tui.run();
}
