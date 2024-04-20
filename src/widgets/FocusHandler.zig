const Rect = @import("../Rect.zig");
const events = @import("../events.zig");
const Frame = @import("../render/Frame.zig");
const Theme = @import("../Theme.zig");

const FocusHandler = @This();

focused: bool = false,

pub fn handle_event(self: *FocusHandler, event: events.Event) events.EventResult {
    switch (event) {
        .FocusIn => {
            self.focused = true;
            return .Consumed;
        },
        .FocusOut => {
            self.focused = false;
            return .Consumed;
        },
        else => {
            return .Ignored;
        },
    }
}

pub fn render(self: *FocusHandler, area: Rect, frame: Frame, _: Theme) void {
    if (self.focused) {
        frame.set_style(area, .{ .add_effect = .{ .highlight = true } });
    }
}
