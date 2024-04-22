const std = @import("std");

pub fn Callback(comptime args: anytype) type {
    const info = @typeInfo(@TypeOf(args));

    comptime if (info == .Type and args == void) {
        return struct {
            const Self = @This();

            cb: *const fn (_: ?*anyopaque) void,
            payload: ?*anyopaque = null,

            pub fn call(self: Self) void {
                self.cb(self.payload);
            }
        };
    } else if (info == .Struct and info.Struct.is_tuple) {
        const tuple = info.Struct;
        return switch (tuple.fields.len) {
            0 => Callback(void),
            1 => Callback(args[0]),
            2 => struct {
                const Self = @This();

                cb: *const fn (_: ?*anyopaque, _: args[0], _: args[1]) void,
                payload: ?*anyopaque = null,

                pub fn call(self: Self, arg0: args[0], arg1: args[1]) void {
                    self.cb(self.payload, arg0, arg1);
                }
            },
            else => @compileError(std.fmt.comptimePrint("tuples of length {d} are not supported", .{tuple.fields.len})),
        };
    } else {
        return struct {
            const Self = @This();

            cb: *const fn (_: ?*anyopaque, _: args) void,
            payload: ?*anyopaque = null,

            pub fn call(self: Self, data: args) void {
                self.cb(self.payload, data);
            }
        };
    };
}

const TestReceiver = struct {
    var called: bool = false;
    received: bool = false,
    a: u32 = 0,
    b: u32 = 0,

    pub fn f0(ptr: ?*anyopaque) void {
        called = true;
        if (ptr) |self| {
            const recv: *TestReceiver = @ptrCast(@alignCast(self));
            recv.received = true;
        }
    }
    pub fn f1(ptr: ?*anyopaque, arg: u32) void {
        f0(ptr);
        if (ptr) |self| {
            const recv: *TestReceiver = @ptrCast(@alignCast(self));
            recv.a = arg;
        }
    }
    pub fn f2(ptr: ?*anyopaque, arg1: u32, arg2: u32) void {
        f1(ptr, arg1);
        if (ptr) |self| {
            const recv: *TestReceiver = @ptrCast(@alignCast(self));
            recv.b = arg2;
        }
    }
};

test "callback with no data and no payload" {
    const cb: Callback(void) = .{
        .cb = TestReceiver.f0,
    };
    cb.call();
    try std.testing.expect(TestReceiver.called);
}

test "callback with no data" {
    var receiver = TestReceiver{};
    const cb: Callback(void) = .{
        .cb = TestReceiver.f0,
        .payload = &receiver,
    };
    cb.call();
    try std.testing.expect(receiver.received);
}

test "callback with one argument and no payload" {
    const cb: Callback(u32) = .{
        .cb = TestReceiver.f1,
    };
    cb.call(1);
    try std.testing.expect(TestReceiver.called);
}

test "callback with one argument" {
    var receiver = TestReceiver{};
    const cb: Callback(u32) = .{
        .cb = TestReceiver.f1,
        .payload = &receiver,
    };
    cb.call(1);
    try std.testing.expect(receiver.received);
    try std.testing.expect(receiver.a == 1);
}

test "callback with two arguments and no payload" {
    const cb: Callback(.{ u32, u32 }) = .{
        .cb = TestReceiver.f2,
    };
    cb.call(1, 2);
    try std.testing.expect(TestReceiver.called);
}

test "callback with two arguments" {
    var receiver = TestReceiver{};
    const cb: Callback(.{ u32, u32 }) = .{
        .cb = TestReceiver.f2,
        .payload = &receiver,
    };
    cb.call(1, 2);
    try std.testing.expect(receiver.received);
    try std.testing.expect(receiver.a == 1);
    try std.testing.expect(receiver.b == 2);
}

test "tuple arguments coercion" {
    try std.testing.expect(Callback(void) == Callback(.{}));

    try std.testing.expect(Callback(.{u32}) == Callback(u32));
}
