const std = @import("std");
const tuile = @import("tuile");

const FPSCounter = struct {
    const Config = struct {
        layout: tuile.LayoutProperties = .{},
    };

    pub usingnamespace tuile.Widget.LeafWidget.Mixin(FPSCounter);

    allocator: std.mem.Allocator,

    layout_properties: tuile.LayoutProperties,

    last_timestamp: ?std.time.Instant = null,

    frames: usize = 0,

    buffer: ["999.99".len]u8 = undefined,
    const buffer_fmt = "{d: >6.2}";

    const window_size: usize = 60;

    pub fn create(allocator: std.mem.Allocator, config: Config) !*FPSCounter {
        const self = try allocator.create(FPSCounter);
        self.* = FPSCounter{
            .allocator = allocator,
            .layout_properties = config.layout,
        };
        std.mem.copyForwards(u8, &self.buffer, "  0.00");
        return self;
    }

    pub fn destroy(self: *FPSCounter) void {
        self.allocator.destroy(self);
    }

    pub fn widget(self: *FPSCounter) tuile.Widget {
        return tuile.Widget.init(self);
    }

    pub fn render(self: *FPSCounter, area: tuile.Rect, frame: tuile.render.Frame, _: tuile.Theme) !void {
        self.frames += 1;
        if (self.frames >= window_size) {
            const now = try std.time.Instant.now();
            const prev = if (self.last_timestamp) |ts| ts else now;
            const elapsed_ns = now.since(prev);
            const elapsed_s = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(std.time.ns_per_s));
            const fps = @as(f64, @floatFromInt(self.frames)) / elapsed_s;
            const clamped: f64 = std.math.clamp(fps, 0, 999);

            var list = std.ArrayListUnmanaged(u8).fromOwnedSlice(&self.buffer);
            list.clearRetainingCapacity();
            const writer = list.fixedWriter();
            _ = try std.fmt.format(writer, buffer_fmt, .{clamped});

            self.last_timestamp = now;
            self.frames = 0;
        }

        _ = try frame.writeSymbols(area.min, &self.buffer, area.width());
    }

    pub fn layout(self: *FPSCounter, _: tuile.Constraints) !tuile.Vec2 {
        return .{ .x = @intCast(self.buffer.len), .y = 1 };
    }

    pub fn handleEvent(_: *FPSCounter, _: tuile.events.Event) !tuile.events.EventResult {
        return .ignored;
    }

    pub fn layoutProps(self: *FPSCounter) tuile.LayoutProperties {
        return self.layout_properties;
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
            .{ .layout = .{ .flex = 1 } },
            FPSCounter.create(allocator, .{}),
        )},
    );

    try tui.add(layout);

    try tui.run();
}
