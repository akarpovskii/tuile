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

// Make it user-driven?
const FRAMES_PER_SECOND = 30;
const FRAME_TIME_NS = std.time.ns_per_s / FRAMES_PER_SECOND;

pub const Tuile = struct {
    backend: backends.Backend,

    is_running: bool = true,

    root: *widgets.StackLayout,

    theme: display.Theme = .{},

    last_frame_time: u64,
    last_sleep_error: i64,

    pub fn init() !Tuile {
        const curses = try backends.Ncurses.create();
        const root = try widgets.StackLayout.create(.{ .orientation = .vertical }, .{});

        return .{
            .backend = curses.backend(),
            .root = root,
            .last_frame_time = 0,
            .last_sleep_error = 0,
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
            var frame_timer = try std.time.Timer.start();

            var prepared = false;
            while (try self.backend.pollEvent()) |event| {
                switch (try self.handleEvent(event)) {
                    .consumed => continue,
                    .ignored => {
                        if (!prepared) {
                            try self.prepare();
                            prepared = true;
                        }
                        try self.propagateEvent(event);
                    },
                }
            }

            if (!prepared) {
                try self.prepare();
            }
            try self.redraw();

            self.last_frame_time = frame_timer.lap();

            const total_frame_time: i64 = @as(i64, @intCast(self.last_frame_time)) + self.last_sleep_error;
            if (total_frame_time < FRAME_TIME_NS) {
                const left_until_frame = FRAME_TIME_NS - @as(u64, @intCast(total_frame_time));

                var sleep_timer = try std.time.Timer.start();
                std.time.sleep(left_until_frame);
                const actual_sleep_time = sleep_timer.lap();

                self.last_sleep_error = @as(i64, @intCast(actual_sleep_time)) - @as(i64, @intCast(left_until_frame));
            }
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

        var buffer = try std.ArrayListUnmanaged(render.Cell).initCapacity(internal.allocator, window_size.x * window_size.y);
        defer buffer.deinit(internal.allocator);
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

    fn handleEvent(self: *Tuile, event: events.Event) !events.EventResult {
        switch (event) {
            .ctrl_char => |value| {
                if (value == 'c') {
                    self.is_running = false;
                    // pass down the event to widgets
                    return .ignored;
                }
            },
            .key => |key| if (key == .Resize)
                return .consumed,
            else => {},
        }
        return .ignored;
    }

    fn propagateEvent(self: *Tuile, event: events.Event) !void {
        _ = try self.root.handleEvent(event);
    }
};
