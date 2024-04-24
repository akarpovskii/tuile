const std = @import("std");
const tuile = @import("tuile");

const CheckedState = struct {
    checked: [3]bool = .{ false, false, false },

    notifier: tuile.ChangeNotifier = tuile.ChangeNotifier.init(),
    pub usingnamespace tuile.ChangeNotifier.Mixin(@This(), .notifier);

    pub fn onGroupState(ptr: ?*anyopaque, idx: usize, state: bool) void {
        var self: *CheckedState = @ptrCast(@alignCast(ptr.?));
        self.checked[idx] = state;
        self.notifyListeners();
    }

    pub fn onState0(ptr: ?*anyopaque, state: bool) void {
        var self: *CheckedState = @ptrCast(@alignCast(ptr.?));
        self.checked[0] = state;
        self.notifyListeners();
    }

    pub fn onState1(ptr: ?*anyopaque, state: bool) void {
        var self: *CheckedState = @ptrCast(@alignCast(ptr.?));
        self.checked[1] = state;
        self.notifyListeners();
    }

    pub fn onState2(ptr: ?*anyopaque, state: bool) void {
        var self: *CheckedState = @ptrCast(@alignCast(ptr.?));
        self.checked[2] = state;
        self.notifyListeners();
    }
};

const StateView = struct {
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

    pub fn build(_: *StateView, context: *tuile.StatefulWidget.BuildContext) !tuile.Widget {
        const state = try context.watch(CheckedState);
        var labels: [3][]const u8 = undefined;
        for (&labels, labels_on, labels_off, state.checked) |*label, on, off, checked| {
            if (checked) {
                label.* = on;
            } else {
                label.* = off;
            }
        }
        const widget = try tuile.vertical(.{}, .{
            tuile.label(.{ .text = labels[0] }),
            tuile.label(.{ .text = labels[1] }),
            tuile.label(.{ .text = labels[2] }),
        });
        return widget.widget();
    }
};

pub fn main() !void {
    var tui = try tuile.Tuile.init(.{});
    defer tui.deinit();

    var state1 = CheckedState{};
    var state2 = CheckedState{};
    var view1 = StateView{};
    var view2 = StateView{};

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
                                .on_state_change = .{ .cb = CheckedState.onState0, .payload = &state1 },
                            }),
                            tuile.checkbox(.{
                                .text = "Option 2",
                                .on_state_change = .{ .cb = CheckedState.onState1, .payload = &state1 },
                            }),
                            tuile.checkbox(.{
                                .text = "Option 3",
                                .on_state_change = .{ .cb = CheckedState.onState2, .payload = &state1 },
                            }),
                        },
                    ),
                    tuile.stateful(&view1, &state1),
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
                            .on_state_change = .{ .cb = CheckedState.onGroupState, .payload = &state2 },
                        },
                        .{
                            tuile.checkbox(.{ .text = "Option 1" }),
                            tuile.checkbox(.{ .text = "Option 2" }),
                            tuile.checkbox(.{ .text = "Option 3" }),
                        },
                    ),
                    tuile.stateful(&view2, &state2),
                }),
            ),
            tuile.spacer(.{}),
        },
    );

    try tui.add(layout);

    try tui.run();
}
