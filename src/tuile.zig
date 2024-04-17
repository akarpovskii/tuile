const std = @import("std");

pub const widgets = @import("widgets/widgets.zig");
pub const backends = @import("backends/backends.zig");
pub const render = @import("render/render.zig");

pub const Style = @import("Style.zig");
pub const Vec2 = @import("Vec2.zig");
pub const Rect = @import("Rect.zig");

pub const events = @import("events.zig");

pub const Color = @import("color.zig").Color;
pub const border = @import("border.zig");

pub const Tuile = struct {
    allocator: std.mem.Allocator,

    backend: backends.Backend,

    is_running: bool = true,

    root: *widgets.StackLayout,

    pub fn init(allocator: std.mem.Allocator) !Tuile {
        var curses = try backends.Ncurses.init();
        const root = try widgets.StackLayout.create(allocator, .{ .orientation = .Vertical }, .{});

        return .{
            .allocator = allocator,
            .backend = curses.backend(),
            .root = root,
        };
    }

    pub fn deinit(self: *Tuile) !void {
        try self.backend.deinit();
        self.root.destroy();
    }

    pub fn add(self: *Tuile, child: widgets.Widget) !void {
        try self.root.add(child);
    }

    pub fn run(self: *Tuile) !void {
        while (self.is_running) {
            const event = try self.backend.poll_event();
            if (event) |value| {
                try self.propagate_event(value);
            }

            try self.redraw();
        }
    }

    fn redraw(self: *Tuile) !void {
        const window_size = try self.backend.window_size();
        const area = Rect{
            .min = Vec2.zero(),
            .max = window_size,
        };
        var frame = try render.Frame.init(self.allocator, window_size);
        defer frame.deinit();

        try self.root.layout(window_size);

        try self.root.render(area, &frame);

        try self.render_frame(&frame);
    }

    fn propagate_event(self: *Tuile, event: events.Event) !void {
        switch (event) {
            .CtrlChar => |value| {
                if (value == 'c') {
                    self.is_running = false;
                }
            },
            else => {},
        }
        _ = try self.root.handle_event(event);
    }

    fn render_frame(self: *Tuile, frame: *render.Frame) !void {
        for (0..frame.size.x) |x| {
            for (0..frame.size.y) |y| {
                const pos = Vec2{ .x = @intCast(x), .y = @intCast(y) };
                const cell = frame.at(pos);
                try self.backend.enable_effect(cell.effect);
                if (cell.symbol) |symbol| {
                    try self.backend.print_at(pos, symbol);
                }
                try self.backend.disable_effect(cell.effect);
            }
        }
        try self.backend.refresh();
    }
};
