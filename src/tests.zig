const std = @import("std");

comptime {
    _ = @import("widgets/ChangeNotifier.zig");
    _ = @import("widgets/callbacks.zig");
    _ = @import("display/span.zig");
    _ = @import("display/colors.zig");
}

test {
    std.testing.refAllDecls(@This());
}
