const std = @import("std");
const tuile = @import("tuile");

const AppState = struct {
    allocator: std.mem.Allocator,

    mutex: std.Thread.Mutex,

    thread: std.Thread,

    stop: bool = false,

    progress: usize,

    notifier: tuile.ChangeNotifier,
    pub usingnamespace tuile.ChangeNotifier.Mixin(@This(), .notifier);

    const progress_step: usize = 5;

    pub fn init(allocator: std.mem.Allocator) !*AppState {
        const self = try allocator.create(AppState);
        errdefer allocator.destroy(self);
        self.* = AppState{
            .allocator = allocator,
            .progress = 0,
            .notifier = tuile.ChangeNotifier.init(),
            .mutex = std.Thread.Mutex{},
            .thread = try std.Thread.spawn(.{}, AppState.update_loop, .{self}),
        };
        return self;
    }

    pub fn deinit(self: *AppState) void {
        self.mutex.lock();
        self.stop = true;
        self.mutex.unlock();
        self.thread.join();

        self.notifier.deinit();
        self.allocator.destroy(self);
    }

    pub fn update_loop(self: *AppState) void {
        while (true) {
            std.time.sleep(100 * std.time.ns_per_ms);

            self.mutex.lock();
            defer self.mutex.unlock();

            if (self.stop) break;
            if (self.progress == 100) continue;

            self.progress += progress_step;
            self.notifyListeners();
        }
    }

    pub fn onReset(ptr: ?*anyopaque) void {
        const self: *AppState = @ptrCast(@alignCast(ptr.?));
        self.mutex.lock();
        defer self.mutex.unlock();
        self.progress = 0;
        self.notifyListeners();
    }
};

const ProgressView = struct {
    pub fn build(_: *ProgressView, context: *tuile.StatefulWidget.BuildContext) !tuile.Widget {
        const state = try context.watch(AppState);
        state.mutex.lock();
        defer state.mutex.unlock();

        const steps: usize = 100 / AppState.progress_step;
        const filled = state.progress / AppState.progress_step;
        var buffer: [steps * "█".len]u8 = undefined;
        var bar = buffer[0 .. filled * "█".len];
        for (0..filled) |i| {
            std.mem.copyForwards(u8, bar[i * "█".len ..], "█");
        }

        const stack = try tuile.stack_layout(
            .{ .orientation = .vertical, .layout = .{ .flex = 1 } },
            .{
                tuile.label(.{ .text = bar, .layout = .{ .alignment = tuile.LayoutProperties.Align.center() } }),
                tuile.spacer(.{ .layout = .{ .max_width = 1, .max_height = 1 } }),
            },
        );

        if (state.progress == 100) {
            try stack.add(
                tuile.button(.{
                    .label = "Restart",
                    .on_press = .{
                        .cb = AppState.onReset,
                        .payload = state,
                    },
                }),
            );
        } else {
            try stack.add(
                tuile.spacer(.{ .layout = .{ .max_width = 1, .max_height = 1 } }),
            );
        }

        const widget = try tuile.block(
            .{ .border = tuile.border.Border.all(), .layout = .{ .flex = 1 } },
            stack,
        );
        return widget.widget();
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var tui = try tuile.Tuile.init();
    defer {
        tui.deinit() catch {
            std.debug.print("Failed to deinit ncurses", .{});
        };
    }

    var app_state = try AppState.init(allocator);
    defer app_state.deinit();
    var progress_view = ProgressView{};

    const layout = tuile.stack_layout(
        .{ .orientation = .vertical, .layout = .{ .flex = 1 } },
        .{
            tuile.stateful(&progress_view, app_state),
        },
    );

    try tui.add(layout);

    try tui.run();
}
