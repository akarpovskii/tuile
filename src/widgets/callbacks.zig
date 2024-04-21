pub fn Callback(DataType: type) type {
    comptime if (DataType == void) {
        return struct {
            const Self = @This();

            cb: *const fn (_: ?*anyopaque) void,
            payload: ?*anyopaque = null,

            pub fn call(self: Self) void {
                self.cb(self.payload);
            }
        };
    } else {
        return struct {
            const Self = @This();

            cb: *const fn (_: *anyopaque, _: DataType) void,
            payload: *anyopaque,

            pub fn call(self: Self, data: DataType) void {
                self.cb(self.payload, data);
            }
        };
    };
}
