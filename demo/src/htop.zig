const std = @import("std");
const tuile = @import("tuile");
const widgets = tuile.widgets;
const Align = widgets.LayoutProperties.Align;
const BuildContext = StatefulWidget.BuildContext;
const ChangeNotifier = widgets.ChangeNotifier;
const Label = widgets.Label;
const LayoutProperties = widgets.LayoutProperties;
const Spacer = widgets.Spacer;
const StackLayout = widgets.StackLayout;
const StatefulWidget = widgets.StatefulWidget;
const Widget = widgets.Widget;

const Process = struct {
    const Param = enum {
        pid,
        user,
        virt,
        res,
        cpu,
        mem,
        time,
        command,
    };
    params: [@typeInfo(Param).Enum.fields.len][]const u8,
};

const AppState = struct {
    allocator: std.mem.Allocator,

    processes: std.ArrayList(Process),

    notifier: ChangeNotifier,

    mutex: std.Thread.Mutex,

    thread: std.Thread,

    stop: bool = false,

    pub usingnamespace ChangeNotifier.Mixin(@This(), "notifier");

    pub fn init(allocator: std.mem.Allocator) !*AppState {
        const self = try allocator.create(AppState);
        errdefer allocator.destroy(self);
        self.* = AppState{
            .allocator = allocator,
            .processes = std.ArrayList(Process).init(allocator),
            .notifier = ChangeNotifier.init(allocator),
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

        for (self.processes.items) |proc| {
            for (proc.params) |param| {
                self.allocator.free(param);
            }
        }
        self.notifier.deinit();
        self.processes.deinit();
        self.allocator.destroy(self);
    }

    pub fn update_loop(self: *AppState) void {
        var prng = std.rand.DefaultPrng.init(1234567);
        const rand = prng.random();

        const allocPrint = std.fmt.allocPrint;

        var count: u32 = 0;
        while (true) {
            std.time.sleep(1 * std.time.ns_per_s);

            self.mutex.lock();
            if (self.stop) break;
            self.mutex.unlock();

            // TODO: Show actual processes
            if (count < 20) {
                var process = Process{ .params = undefined };
                const P = Process.Param;

                const pid = allocPrint(self.allocator, "{d}", .{count}) catch break;
                errdefer self.allocator.free(pid);

                const user = self.allocator.dupe(u8, "user") catch break;
                errdefer self.allocator.free(user);

                const virt = allocPrint(self.allocator, "{d}", .{rand.intRangeAtMost(u32, 1000, 9999)}) catch break;
                errdefer self.allocator.free(virt);

                const res = allocPrint(self.allocator, "{d}", .{rand.intRangeAtMost(u32, 1000, 9999)}) catch break;
                errdefer self.allocator.free(res);

                const cpu = allocPrint(self.allocator, "{d}", .{rand.uintLessThan(u32, 100)}) catch break;
                errdefer self.allocator.free(cpu);

                const mem = allocPrint(self.allocator, "{d}", .{rand.uintLessThan(u32, 100)}) catch break;
                errdefer self.allocator.free(mem);

                const h = rand.uintLessThan(u32, 24);
                const m = rand.uintLessThan(u32, 60);
                const s = rand.uintLessThan(u32, 60);
                const time = allocPrint(self.allocator, "{d:2}h{d:0>2}:{d:0>2}", .{ h, m, s }) catch break;
                errdefer self.allocator.free(time);

                const command = self.allocator.dupe(u8, "/dev/null") catch break;
                errdefer self.allocator.free(command);

                process.params[@intFromEnum(P.pid)] = pid;
                process.params[@intFromEnum(P.user)] = user;
                process.params[@intFromEnum(P.virt)] = virt;
                process.params[@intFromEnum(P.res)] = res;
                process.params[@intFromEnum(P.cpu)] = cpu;
                process.params[@intFromEnum(P.mem)] = mem;

                process.params[@intFromEnum(P.time)] = time;
                process.params[@intFromEnum(P.command)] = command;

                self.mutex.lock();
                defer self.mutex.unlock();
                self.processes.append(process) catch break;
                count += 1;

                self.notifyListeners();
            } else {}
        }
    }
};

const ProcessListView = struct {
    const ColNames = std.ComptimeStringMap([]const u8, .{
        .{ "pid", "PID" },
        .{ "user", "USER" },
        .{ "virt", "VIRT" },
        .{ "res", "RES" },
        .{ "cpu", "CPU%" },
        .{ "mem", "MEM%" },
        .{ "time", "TIME+" },
        .{ "command", "Command" },
    });

    const ColLayout = std.ComptimeStringMap(LayoutProperties, .{
        .{ "pid", .{ .min_width = 5, .max_width = 5, .alignment = Align.topLeft() } },
        .{ "user", .{ .min_width = 10, .max_width = 10, .alignment = Align.topLeft() } },
        .{ "virt", .{ .min_width = 5, .max_width = 5, .alignment = Align.topLeft() } },
        .{ "res", .{ .min_width = 5, .max_width = 5, .alignment = Align.topLeft() } },
        .{ "cpu", .{ .min_width = 4, .max_width = 4, .alignment = Align.topLeft() } },
        .{ "mem", .{ .min_width = 4, .max_width = 4, .alignment = Align.topLeft() } },
        .{ "time", .{ .min_width = 8, .max_width = 8, .alignment = Align.topLeft() } },
        .{ "command", .{ .flex = 1, .alignment = Align.topLeft() } },
    });

    allocator: std.mem.Allocator,

    pub fn build(self: *ProcessListView, context: *BuildContext) !Widget {
        const state = try context.watch(AppState);
        state.mutex.lock();

        const columns_count = @typeInfo(Process.Param).Enum.fields.len;
        var columns: [columns_count * 2 - 1]Widget = undefined;

        for (0..columns_count) |idx| {
            if (idx > 0) {
                const spacer = try Spacer.create(self.allocator, .{ .layout = .{ .max_height = 1, .max_width = 1 } });
                columns[idx * 2 - 1] = spacer.widget();
            }
            columns[idx * 2] = try self.buildColumn(state, @enumFromInt(idx));
        }

        const widget = try widgets.StackLayout.create(
            self.allocator,
            .{ .orientation = .horizontal, .layout = .{ .flex = 2 } },
            columns,
        );
        state.mutex.unlock();
        return widget.widget();
    }

    fn buildColumn(self: *ProcessListView, state: *AppState, param: Process.Param) !Widget {
        var lines = try std.ArrayList(*Label).initCapacity(self.allocator, state.processes.items.len + 1);
        defer lines.deinit();

        const layout = ColLayout.get(@tagName(param)).?;
        lines.append(try Label.create(self.allocator, .{
            .text = ColNames.get(@tagName(param)).?,
            .layout = .{
                .min_width = layout.min_width,
                .min_height = layout.min_height,
                .alignment = layout.alignment,
            },
        })) catch unreachable;

        for (state.processes.items) |process| {
            lines.append(try Label.create(self.allocator, .{
                .text = process.params[@intFromEnum(param)],
                .layout = .{
                    .min_width = layout.min_width,
                    .min_height = layout.min_height,
                    .alignment = layout.alignment,
                },
            })) catch unreachable;
        }

        const column = try StackLayout.create(
            self.allocator,
            .{ .layout = layout },
            lines.items,
        );

        return column.widget();
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var tui = try tuile.Tuile.init(allocator);
    defer {
        tui.deinit() catch {
            std.debug.print("Failed to deinit ncurses", .{});
        };
    }

    var app_state = try AppState.init(allocator);
    defer app_state.deinit();
    var plist_view = ProcessListView{ .allocator = allocator };

    const layout = try widgets.StackLayout.create(
        allocator,
        .{ .orientation = .vertical, .layout = .{ .flex = 1 } },
        .{
            try widgets.Block.create(
                allocator,
                .{ .border = widgets.border.Border.all(), .layout = .{ .flex = 1 } },
                try widgets.StackLayout.create(
                    allocator,
                    .{ .orientation = .horizontal },
                    .{},
                ),
            ),

            try StatefulWidget.create(
                allocator,
                &plist_view,
                app_state,
            ),
        },
    );

    try tui.add(layout.widget());

    try tui.run();
}
