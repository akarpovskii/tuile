const std = @import("std");
const tuile = @import("tuile");

const AppState = struct {
    allocator: std.mem.Allocator,

    mutex: std.Thread.Mutex,

    thread: std.Thread,

    stop: bool = false,

    progress: usize,

    tui: *tuile.Tuile,

    const progress_step: usize = 5;

    pub fn init(allocator: std.mem.Allocator, tui: *tuile.Tuile) !*AppState {
        const self = try allocator.create(AppState);
        errdefer allocator.destroy(self);
        self.* = AppState{
            .allocator = allocator,
            .progress = 0,
            .mutex = std.Thread.Mutex{},
            .thread = try std.Thread.spawn(.{}, AppState.update_loop, .{self}),
            .tui = tui,
        };
        return self;
    }

    pub fn deinit(self: *AppState) void {
        self.mutex.lock();
        self.stop = true;
        self.mutex.unlock();
        self.thread.join();

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
            self.tui.scheduleTask(.{ .cb = @ptrCast(&AppState.updateProgress), .payload = self }) catch unreachable;
        }
    }

    pub fn onReset(self_opt: ?*AppState) void {
        const self = self_opt.?;
        {
            self.mutex.lock();
            defer self.mutex.unlock();
            self.progress = 0;
        }

        const stack = self.tui.findByIdTyped(tuile.StackLayout, "progress-stack") orelse unreachable;
        const reset = self.tui.findById("reset-button") orelse unreachable;

        _ = stack.removeChild(reset) catch unreachable;
        stack.addChild(tuile.spacer(.{
            .id = "progress-spacer",
            .layout = .{ .max_width = 1, .max_height = 1 },
        })) catch unreachable;

        // Safe to call, we are in the main thread
        self.updateProgress();
    }

    pub fn updateProgress(self: *AppState) void {
        const progress = blk: {
            self.mutex.lock();
            defer self.mutex.unlock();
            break :blk self.progress;
        };

        const steps: usize = 100 / AppState.progress_step;
        const filled = progress / AppState.progress_step;
        var buffer: [steps * "█".len]u8 = undefined;
        var bar = buffer[0 .. filled * "█".len];
        for (0..filled) |i| {
            std.mem.copyForwards(u8, bar[i * "█".len ..], "█");
        }
        const label = self.tui.findByIdTyped(tuile.Label, "progress-label") orelse unreachable;
        label.setText(bar) catch unreachable;

        if (progress == 100) {
            const stack = self.tui.findByIdTyped(tuile.StackLayout, "progress-stack") orelse unreachable;
            const spacer = self.tui.findById("progress-spacer") orelse unreachable;

            _ = stack.removeChild(spacer) catch unreachable;
            stack.addChild(tuile.button(.{
                .id = "reset-button",
                .text = "Restart",
                .on_press = .{
                    .cb = @ptrCast(&AppState.onReset),
                    .payload = self,
                },
            })) catch unreachable;
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var tui = try tuile.Tuile.init(.{});
    defer tui.deinit();

    const layout = tuile.vertical(
        .{ .layout = .{ .flex = 1 } },
        .{tuile.block(
            .{ .border = tuile.border.Border.all(), .layout = .{ .flex = 1 } },
            tuile.vertical(
                .{ .id = "progress-stack", .layout = .{ .flex = 1 } },
                .{
                    tuile.label(.{ .id = "progress-label", .text = "", .layout = .{ .alignment = tuile.LayoutProperties.Align.center() } }),
                    tuile.spacer(.{ .id = "progress-spacer", .layout = .{ .max_width = 1, .max_height = 1 } }),
                },
            ),
        )},
    );

    try tui.add(layout);

    var app_state = try AppState.init(allocator, &tui);
    defer app_state.deinit();

    try tui.run();
}
