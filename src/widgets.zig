pub const Block = @import("widgets/Block.zig");
pub const border = @import("widgets/border.zig");
pub usingnamespace border;
pub const Button = @import("widgets/Button.zig");
pub const callbacks = @import("widgets/callbacks.zig");
pub const Callback = callbacks.Callback;
pub const Checkbox = @import("widgets/Checkbox.zig");
pub const CheckboxGroup = @import("widgets/CheckboxGroup.zig");
pub const Constraints = @import("widgets/Constraints.zig");
pub const FocusHandler = @import("widgets/FocusHandler.zig");
pub const Input = @import("widgets/Input.zig");
pub const Label = @import("widgets/Label.zig");
pub const LayoutProperties = @import("widgets/LayoutProperties.zig");
pub const Align = LayoutProperties.Align;
pub const HAlign = LayoutProperties.HAlign;
pub const VAlign = LayoutProperties.VAlign;
pub const Padding = @import("widgets/Padding.zig");
pub const Spacer = @import("widgets/Spacer.zig");
pub const StackLayout = @import("widgets/StackLayout.zig");
pub const Themed = @import("widgets/Themed.zig");
pub const Widget = @import("widgets/Widget.zig");

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
pub const themed = Themed.create;
