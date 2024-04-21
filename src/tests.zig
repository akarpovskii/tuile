const std = @import("std");

comptime {
    _ = @import("widgets/ChangeNotifier.zig");
}

test {
    std.testing.refAllDecls(@This());
}
