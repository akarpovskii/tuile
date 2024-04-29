const std = @import("std");
const tuile = @import("tuile");

const CheckedState = struct {
    const labels_on: [3][]const u8 = .{
        "State 1 - 1",
        "State 2 - 1",
        "State 3 - 1",
    };

    const labels_off: [3][]const u8 = .{
        "State 1 - 0",
        "State 2 - 0",
        "State 3 - 0",
    };

    checked: [3]bool = .{ false, false, false },

    tui: *tuile.Tuile,

    ids: [3][]const u8,

    pub fn onGroupState(ptr: ?*CheckedState, idx: usize, state: bool) void {
        var self = ptr.?;
        self.checked[idx] = state;
        self.updateLabels();
    }

    pub fn onState0(ptr: ?*CheckedState, state: bool) void {
        var self = ptr.?;
        self.checked[0] = state;
        self.updateLabels();
    }

    pub fn onState1(ptr: ?*CheckedState, state: bool) void {
        var self = ptr.?;
        self.checked[1] = state;
        self.updateLabels();
    }

    pub fn onState2(ptr: ?*CheckedState, state: bool) void {
        var self = ptr.?;
        self.checked[2] = state;
        self.updateLabels();
    }

    fn updateLabels(self: CheckedState) void {
        var labels: [3][]const u8 = undefined;
        for (&labels, labels_on, labels_off, self.checked) |*label, on, off, checked| {
            if (checked) {
                label.* = on;
            } else {
                label.* = off;
            }
        }

        for (self.ids, labels) |id, text| {
            const label = self.tui.findByIdTyped(tuile.Label, id) orelse unreachable;
            label.setText(text) catch unreachable;
        }
    }
};

pub fn main() !void {
    var tui = try tuile.Tuile.init(.{});
    defer tui.deinit();

    var state1 = CheckedState{ .tui = &tui, .ids = [3][]const u8{ "state-1-1", "state-1-2", "state-1-3" } };
    var state2 = CheckedState{ .tui = &tui, .ids = [3][]const u8{ "state-2-1", "state-2-2", "state-2-3" } };

    const layout = tuile.horizontal(
        .{},
        .{
            tuile.spacer(.{}),
            tuile.block(
                .{ .border = tuile.border.Border.all(), .border_type = .double },
                tuile.vertical(.{}, .{
                    tuile.label(.{ .text = "Radio" }),
                    tuile.checkbox_group(
                        .{ .multiselect = false },
                        .{
                            tuile.checkbox(.{
                                .text = "Option 1",
                                .on_state_change = .{ .cb = @ptrCast(&CheckedState.onState0), .payload = &state1 },
                            }),
                            tuile.checkbox(.{
                                .text = "Option 2",
                                .on_state_change = .{ .cb = @ptrCast(&CheckedState.onState1), .payload = &state1 },
                            }),
                            tuile.checkbox(.{
                                .text = "Option 3",
                                .on_state_change = .{ .cb = @ptrCast(&CheckedState.onState2), .payload = &state1 },
                            }),
                        },
                    ),
                    tuile.vertical(.{}, .{
                        tuile.label(.{ .id = state1.ids[0], .text = "" }),
                        tuile.label(.{ .id = state1.ids[1], .text = "" }),
                        tuile.label(.{ .id = state1.ids[2], .text = "" }),
                    }),
                }),
            ),
            tuile.spacer(.{ .layout = .{ .max_width = 10, .max_height = 1 } }),
            tuile.block(
                .{ .border = tuile.border.Border.all(), .border_type = .double },
                tuile.vertical(.{}, .{
                    tuile.label(.{ .text = "Multiselect" }),
                    tuile.checkbox_group(
                        .{
                            .multiselect = true,
                            .on_state_change = .{ .cb = @ptrCast(&CheckedState.onGroupState), .payload = &state2 },
                        },
                        .{
                            tuile.checkbox(.{ .text = "Option 1" }),
                            tuile.checkbox(.{ .text = "Option 2" }),
                            tuile.checkbox(.{ .text = "Option 3" }),
                        },
                    ),
                    tuile.vertical(.{}, .{
                        tuile.label(.{ .id = state2.ids[0], .text = "" }),
                        tuile.label(.{ .id = state2.ids[1], .text = "" }),
                        tuile.label(.{ .id = state2.ids[2], .text = "" }),
                    }),
                }),
            ),
            tuile.spacer(.{}),
        },
    );

    try tui.add(layout);

    state1.updateLabels();
    state2.updateLabels();

    try tui.run();
}
