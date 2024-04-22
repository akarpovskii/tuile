const std = @import("std");
const internal = @import("internal.zig");
pub const Vec2 = @import("Vec2.zig");
pub const Rect = @import("Rect.zig");
pub const backends = @import("backends/backends.zig");
pub const render = @import("render/render.zig");
pub const events = @import("events.zig");
pub const widgets = @import("widgets/widgets.zig");
pub usingnamespace widgets;
pub const display = @import("display/display.zig");
pub usingnamespace display;

pub const Tuile = struct {
    backend: backends.Backend,

    is_running: bool = true,

    root: *widgets.StackLayout,

    theme: display.Theme = .{},

    pub fn init() !Tuile {
        const curses = try backends.Ncurses.create();
        const root = try widgets.StackLayout.create(.{ .orientation = .vertical }, .{});

        return .{
            .backend = curses.backend(),
            .root = root,
        };
    }

    pub fn deinit(self: *Tuile) void {
        self.backend.destroy();
        self.root.destroy();
    }

    pub fn add(self: *Tuile, child: anytype) !void {
        try self.root.add(child);
    }

    pub fn run(self: *Tuile) !void {
        while (self.is_running) {
            try self.prepare();

            const event = try self.backend.pollEvent();
            if (event) |value| {
                try self.propagateEvent(value);
            }

            try self.redraw();
        }
    }

    fn prepare(self: *Tuile) !void {
        try self.root.prepare();
    }

    fn redraw(self: *Tuile) !void {
        const window_size = try self.backend.windowSize();
        const window_area = Rect{
            .min = Vec2.zero(),
            .max = window_size,
        };

        var buffer = try std.ArrayList(render.Cell).initCapacity(internal.allocator, window_size.x * window_size.y);
        defer buffer.deinit();
        buffer.appendNTimesAssumeCapacity(.{ .fg = self.theme.foreground, .bg = self.theme.background }, buffer.capacity);

        var frame = render.Frame{
            .buffer = buffer.items,
            .size = window_size,
            .area = window_area,
        };

        const constraints = .{
            .max_width = window_size.x,
            .max_height = window_size.y,
        };
        _ = try self.root.layout(constraints);

        try self.root.render(window_area, frame, self.theme);

        try frame.render(self.backend);
    }

    fn propagateEvent(self: *Tuile, event: events.Event) !void {
        switch (event) {
            .ctrl_char => |value| {
                if (value == 'c') {
                    self.is_running = false;
                }
            },
            .key => |key| if (key == .Resize) return,
            else => {},
        }

        _ = try self.root.handleEvent(event);
    }
};
