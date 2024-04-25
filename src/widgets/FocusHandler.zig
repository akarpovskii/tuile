const Rect = @import("../Rect.zig");
const events = @import("../events.zig");
const Frame = @import("../render/Frame.zig");
const display = @import("../display/display.zig");

const FocusHandler = @This();

focused: bool = false,

pub fn handleEvent(self: *FocusHandler, event: events.Event) events.EventResult {
    switch (event) {
        .focus_in => {
            self.focused = true;
            return .consumed;
        },
        .focus_out => {
            self.focused = false;
            return .consumed;
        },
        else => {
            return .ignored;
        },
    }
}

pub fn render(self: *FocusHandler, area: Rect, frame: Frame, theme: display.Theme) void {
    if (self.focused) {
        frame.setStyle(area, .{ .bg = theme.focused });
    }
}
