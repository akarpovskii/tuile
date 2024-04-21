const std = @import("std");
const callbacks = @import("callbacks.zig");

const ChangeNotifier = @This();

pub const Listener = callbacks.Callback(void);

allocator: std.mem.Allocator,

listeners: std.ArrayList(Listener),

pub fn init(allocator: std.mem.Allocator) ChangeNotifier {
    return ChangeNotifier{ .allocator = allocator, .listeners = std.ArrayList(Listener).init(allocator) };
}

pub fn deinit(self: *ChangeNotifier) void {
    self.listeners.deinit();
}

pub fn addListener(self: *ChangeNotifier, listener: Listener) !void {
    try self.listeners.append(listener);
}

pub fn removeListener(self: *ChangeNotifier, listener: Listener) void {
    for (self.listeners.items, 0..) |existing, idx| {
        if (std.meta.eql(listener, existing)) {
            _ = self.listeners.orderedRemove(idx);
            break;
        }
    }
}

pub fn notifyListeners(self: ChangeNotifier) void {
    for (self.listeners.items) |listener| {
        listener.call();
    }
}

pub fn Mixin(comptime T: type, notifier: []const u8) type {
    return struct {
        pub fn addListener(context: *T, listener: Listener) !void {
            var self: *ChangeNotifier = &@field(context, notifier);
            try self.addListener(listener);
        }

        pub fn removeListener(context: *T, listener: Listener) void {
            var self: *ChangeNotifier = &@field(context, notifier);
            self.removeListener(listener);
        }

        pub fn notifyListeners(context: *T) void {
            var self: *ChangeNotifier = &@field(context, notifier);
            self.notifyListeners();
        }
    };
}

const TestListener = struct {
    count: usize = 0,

    pub fn listen(ptr: ?*anyopaque) void {
        var self: *TestListener = @ptrCast(@alignCast(ptr.?));
        self.count += 1;
    }
};

test "listeners are notified" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var notifier = ChangeNotifier.init(allocator);
    defer notifier.deinit();

    var listener = TestListener{};
    try notifier.addListener(.{ .cb = TestListener.listen, .payload = &listener });
    notifier.notifyListeners();

    try std.testing.expect(listener.count == 1);
}

test "listeners can be added multiple times" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var notifier = ChangeNotifier.init(allocator);
    defer notifier.deinit();

    var listener = TestListener{};
    try notifier.addListener(.{ .cb = TestListener.listen, .payload = &listener });
    try notifier.addListener(.{ .cb = TestListener.listen, .payload = &listener });
    notifier.notifyListeners();

    try std.testing.expect(listener.count == 2);
}

test "listeners are being removed" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var notifier = ChangeNotifier.init(allocator);
    defer notifier.deinit();

    var listener = TestListener{};
    try notifier.addListener(.{ .cb = TestListener.listen, .payload = &listener });
    notifier.notifyListeners();
    try std.testing.expect(listener.count == 1);

    notifier.removeListener(.{ .cb = TestListener.listen, .payload = &listener });
    notifier.notifyListeners();
    try std.testing.expect(listener.count == 1);
}

test "duplicate listeners are removed only once" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var notifier = ChangeNotifier.init(allocator);
    defer notifier.deinit();

    var listener = TestListener{};
    try notifier.addListener(.{ .cb = TestListener.listen, .payload = &listener });
    try notifier.addListener(.{ .cb = TestListener.listen, .payload = &listener });
    notifier.notifyListeners();
    try std.testing.expect(listener.count == 2);

    notifier.removeListener(.{ .cb = TestListener.listen, .payload = &listener });
    notifier.notifyListeners();
    try std.testing.expect(listener.count == 3);
}

test "mixin adds methods" {
    const MixinNotifier = struct {
        change_notifier: ChangeNotifier,
        usingnamespace ChangeNotifier.Mixin(@This(), "change_notifier");
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var notifier = MixinNotifier{ .change_notifier = ChangeNotifier.init(allocator) };
    defer {
        notifier.change_notifier.deinit();
    }

    var listener = TestListener{};
    try notifier.addListener(.{ .cb = TestListener.listen, .payload = &listener });
    notifier.notifyListeners();
    notifier.removeListener(.{ .cb = TestListener.listen, .payload = &listener });

    try std.testing.expect(listener.count == 1);
}
