const std = @import("std");

pub const widgets = @import("widgets/widgets.zig");
pub const backends = @import("backends/backends.zig");

pub const Painter = @import("Painter.zig");
pub const Style = @import("Style.zig");

pub const events = @import("events.zig");

pub const Tuile = struct {
    allocator: std.mem.Allocator,

    backend: backends.Backend,

    is_running: bool = true,

    root: *widgets.StackLayout(.{ .orientation = .Vertical }, .{}),

    pub fn init(allocator: std.mem.Allocator) !Tuile {
        var curses = try backends.Ncurses.init();
        const root = try widgets.StackLayout(.{ .orientation = .Vertical }, .{}).create(allocator);

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

    pub fn redraw(self: *Tuile) !void {
        var painter = try Painter.init(&self.backend);

        const available = try self.backend.window_size();
        // std.debug.print("\n\nava {any}\n\n", .{available});
        try self.root.layout(available);

        try self.root.draw(&painter);

        try self.backend.refresh();
    }

    pub fn propagate_event(self: *Tuile, event: events.Event) !void {
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
};
