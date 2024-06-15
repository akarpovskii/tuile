const std = @import("std");
const internal = @import("internal.zig");
pub const Vec2 = @import("Vec2.zig");
pub const Rect = @import("Rect.zig");
pub const backends = @import("backends.zig");
pub const render = @import("render.zig");
pub const events = @import("events.zig");
pub const widgets = @import("widgets.zig");
pub usingnamespace widgets;
pub const display = @import("display.zig");
pub usingnamespace display;
const grapheme = @import("grapheme");
const DisplayWidth = @import("DisplayWidth");
pub const text_clustering = @import("text_clustering.zig");

const Task = widgets.Callback(void);

// Make it user-driven?
const FRAMES_PER_SECOND = 30;
const FRAME_TIME_NS = std.time.ns_per_s / FRAMES_PER_SECOND;
const GRAPHEME_CLUSTERING_MODE = 2027; // https://mitchellh.com/writing/grapheme-clusters-in-terminals

pub const EventHandler = struct {
    handler: *const fn (payload: ?*anyopaque, event: events.Event) anyerror!events.EventResult,

    payload: ?*anyopaque = null,

    pub fn call(self: EventHandler, event: events.Event) anyerror!events.EventResult {
        return self.handler(self.payload, event);
    }
};

pub const Tuile = struct {
    const Config = struct {
        // Takes ownership of the backend and destroys it afterwards
        backend: ?backends.Backend = null,
    };

    backend: backends.Backend,

    is_running: std.atomic.Value(bool),

    root: *widgets.StackLayout,

    theme: display.Theme,

    last_frame_time: u64,
    last_sleep_error: i64,

    event_handlers: std.ArrayListUnmanaged(EventHandler),

    frame_buffer: std.ArrayListUnmanaged(render.Cell),
    window_size: Vec2,

    task_queue: std.fifo.LinearFifo(Task, .Dynamic),
    task_queue_mutex: std.Thread.Mutex,

    pub fn init(config: Config) !Tuile {
        const backend = if (config.backend) |backend| backend else try backends.createBackend();
        errdefer backend.destroy();
        const text_clustering_type: text_clustering.ClusteringType =
            switch (try backend.requestMode(GRAPHEME_CLUSTERING_MODE)) {
            .not_recognized, .reset => .codepoints,
            .set => .graphemes,
        };

        try internal.init(text_clustering_type);
        var self = blk: {
            const root = try widgets.StackLayout.create(.{ .orientation = .vertical }, .{});
            errdefer root.destroy();

            break :blk Tuile{
                .backend = backend,
                .is_running = std.atomic.Value(bool).init(false),
                .root = root,
                .theme = display.Theme.sky(),
                .last_frame_time = 0,
                .last_sleep_error = 0,
                .event_handlers = .{},
                .frame_buffer = .{},
                .window_size = Vec2.zero(),
                .task_queue = std.fifo.LinearFifo(Task, .Dynamic).init(internal.allocator),
                .task_queue_mutex = .{},
            };
        };
        errdefer self.deinit();
        try self.handleResize();
        return self;
    }

    pub fn deinit(self: *Tuile) void {
        self.task_queue.deinit();
        self.backend.destroy();
        self.frame_buffer.deinit(internal.allocator);
        self.root.destroy();
        internal.deinit();
    }

    pub fn add(self: *Tuile, child: anytype) !void {
        try self.root.addChild(child);
    }

    pub fn findById(self: *Tuile, id: []const u8) ?widgets.Widget {
        return self.root.widget().findById(id);
    }

    pub fn findByIdTyped(self: *Tuile, comptime T: type, id: []const u8) ?*T {
        if (self.root.widget().findById(id)) |found| {
            return found.as(T);
        }
        return null;
    }

    pub fn scheduleTask(self: *Tuile, task: Task) !void {
        self.task_queue_mutex.lock();
        defer self.task_queue_mutex.unlock();
        try self.task_queue.writeItem(task);
    }

    pub fn addEventHandler(self: *Tuile, handler: EventHandler) !void {
        try self.event_handlers.append(internal.allocator, handler);
    }

    pub fn stop(self: *Tuile) void {
        self.is_running.store(false, .release);
    }

    pub fn step(self: *Tuile) !void {
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

        const queued_task = blk: {
            self.task_queue_mutex.lock();
            defer self.task_queue_mutex.unlock();
            break :blk self.task_queue.readItem();
        };
        if (queued_task) |task| {
            task.call();
        }

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

    pub fn run(self: *Tuile) !void {
        self.is_running.store(true, .release);
        while (self.is_running.load(.acquire)) {
            try self.step();
        }
    }

    fn prepare(self: *Tuile) !void {
        try self.root.prepare();
    }

    fn redraw(self: *Tuile) !void {
        const constraints = .{
            .max_width = self.window_size.x,
            .max_height = self.window_size.y,
        };
        _ = try self.root.layout(constraints);

        var frame = render.Frame{
            .buffer = self.frame_buffer.items,
            .size = self.window_size,
            .area = .{
                .min = Vec2.zero(),
                .max = self.window_size,
            },
        };
        frame.clear(self.theme.text_primary, self.theme.background_primary);

        try self.root.render(frame.area, frame, self.theme);

        try frame.render(self.backend);
    }

    fn handleEvent(self: *Tuile, event: events.Event) !events.EventResult {
        for (self.event_handlers.items) |handler| {
            switch (try handler.call(event)) {
                .consumed => return .consumed,
                .ignored => {},
            }
        }

        switch (event) {
            .ctrl_char => |value| {
                if (value == 'c') {
                    self.stop();
                    // pass down the event to widgets
                    return .ignored;
                }
            },
            .key => |key| if (key == .Resize) {
                try self.handleResize();
                return .consumed;
            },
            else => {},
        }
        return .ignored;
    }

    fn propagateEvent(self: *Tuile, event: events.Event) !void {
        _ = try self.root.handleEvent(event);
    }

    fn handleResize(self: *Tuile) !void {
        self.window_size = try self.backend.windowSize();
        const new_len = self.window_size.x * self.window_size.y;
        try self.frame_buffer.resize(internal.allocator, new_len);
    }
};
