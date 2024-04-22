const std = @import("std");

comptime {
    _ = @import("widgets/ChangeNotifier.zig");
    _ = @import("widgets/callbacks.zig");
}

test {
    std.testing.refAllDecls(@This());
}
