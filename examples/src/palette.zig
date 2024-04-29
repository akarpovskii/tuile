const std = @import("std");
const tuile = @import("tuile");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const tuile_allocator = gpa.allocator();

fn generatePalette() !tuile.Span {
    var span = tuile.Span.init(tuile_allocator);
    for (1..257) |i| {
        const rgb = tuile.Palette256.lookup_table[i - 1];
        const bg = tuile.Color{ .rgb = .{ .r = rgb[0], .g = rgb[1], .b = rgb[2] } };
        const fg = tuile.Color{
            .rgb = if (std.mem.max(u8, &rgb) >= 224)
                tuile.Rgb.black()
            else
                tuile.Rgb.white(),
        };

        const fmt: []const u8 = "{d: >4} ";
        const fmt_count = comptime std.fmt.count(fmt, .{256});
        var i_text: [fmt_count]u8 = undefined;
        _ = std.fmt.bufPrint(&i_text, fmt, .{i}) catch unreachable;

        if (i <= 16) {
            try span.append(.{ .text = &i_text, .style = .{ .fg = fg, .bg = bg } });
            if (i == 16) {
                try span.appendPlain("\n");
            }
        } else if (i <= 232) {
            try span.append(.{ .text = &i_text, .style = .{ .fg = fg, .bg = bg } });
            if ((i - 16) % 18 == 0) {
                try span.appendPlain("\n");
            }
        } else {
            try span.append(.{ .text = &i_text, .style = .{ .fg = fg, .bg = bg } });
            if ((i - 232) % 12 == 0) {
                try span.appendPlain("\n");
            }
        }
    }
    return span;
}

const ShowRGB = struct {
    label: *tuile.Label,

    pub fn inputChanged(opt_self: ?*ShowRGB, value: []const u8) void {
        const self = opt_self.?;

        const palette_idx = std.fmt.parseInt(u8, value, 10) catch return;
        const rgb = tuile.Palette256.lookup_table[palette_idx - 1];

        const fmt: []const u8 = "({d: >3}, {d: >3}, {d: >3})";
        const fmt_count = comptime std.fmt.count(fmt, .{ 256, 256, 256 });
        var rgb_text: [fmt_count]u8 = undefined;
        _ = std.fmt.bufPrint(&rgb_text, fmt, .{ rgb[0], rgb[1], rgb[2] }) catch unreachable;

        self.label.setText(&rgb_text) catch unreachable;
    }
};

pub fn main() !void {
    defer _ = gpa.deinit();

    var tui = try tuile.Tuile.init(.{});
    defer tui.deinit();

    var palette = try generatePalette();
    defer palette.deinit();

    var show_rgb: ShowRGB = undefined;

    try tui.add(
        tuile.vertical(
            .{ .layout = .{ .flex = 1 } },
            .{
                tuile.label(.{ .span = palette.view() }),
                tuile.spacer(.{ .layout = .{ .max_height = 1, .max_width = 1 } }),
                tuile.label(.{ .id = "rgb-value", .text = "(..., ..., ...)", .span = palette.view() }),
                tuile.input(.{
                    .placeholder = "index",
                    .layout = .{ .min_width = 5, .max_width = 5 },
                    .on_value_changed = .{ .cb = @ptrCast(&ShowRGB.inputChanged), .payload = &show_rgb },
                }),
            },
        ),
    );

    const label = tui.findByIdTyped(tuile.Label, "rgb-value") orelse unreachable;

    show_rgb = ShowRGB{ .label = label };

    try tui.run();
}
