pub const Block = @import("Block.zig");
pub const border = @import("border.zig");
pub usingnamespace border;
pub const Button = @import("Button.zig");
pub const callbacks = @import("callbacks.zig");
pub const Callback = callbacks.Callback;
pub const ChangeNotifier = @import("ChangeNotifier.zig");
pub const Checkbox = @import("Checkbox.zig");
pub const CheckboxGroup = @import("CheckboxGroup.zig");
pub const Constraints = @import("Constraints.zig");
pub const FocusHandler = @import("FocusHandler.zig");
pub const Input = @import("Input.zig");
pub const Label = @import("Label.zig");
pub const LayoutProperties = @import("LayoutProperties.zig");
pub const Align = LayoutProperties.Align;
pub const HAlign = LayoutProperties.HAlign;
pub const VAlign = LayoutProperties.VAlign;
pub const Padding = @import("Padding.zig");
pub const Spacer = @import("Spacer.zig");
pub const StackLayout = @import("StackLayout.zig");
pub const StatefulWidget = @import("StatefulWidget.zig");
pub const Themed = @import("Themed.zig");
pub const Widget = @import("Widget.zig");

pub const block = Block.create;
pub const button = Button.create;
pub const checkbox = Checkbox.create;
pub const checkbox_group = CheckboxGroup.create;
pub const input = Input.create;
pub const label = Label.create;
pub const spacer = Spacer.create;
pub const stack_layout = StackLayout.create;
pub fn horizontal(config: StackLayout.Config, children: anytype) !*StackLayout {
    var cfg = config;
    cfg.orientation = .horizontal;
    return StackLayout.create(cfg, children);
}
pub fn vertical(config: StackLayout.Config, children: anytype) !*StackLayout {
    var cfg = config;
    cfg.orientation = .vertical;
    return StackLayout.create(cfg, children);
}
pub const stateful = StatefulWidget.create;
pub const themed = Themed.create;
