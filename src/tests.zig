const std = @import("std");

comptime {
    _ = @import("widgets/ChangeNotifier.zig");
    _ = @import("widgets/callbacks.zig");
    _ = @import("display/span.zig");
}

test {
    std.testing.refAllDecls(@This());
}
