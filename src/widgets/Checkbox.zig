const std = @import("std");
const internal = @import("../internal.zig");
const Widget = @import("Widget.zig");
const Vec2 = @import("../Vec2.zig");
const Rect = @import("../Rect.zig");
const events = @import("../events.zig");
const Frame = @import("../render/Frame.zig");
const Label = @import("Label.zig");
const FocusHandler = @import("FocusHandler.zig");
const LayoutProperties = @import("LayoutProperties.zig");
const Constraints = @import("Constraints.zig");
const display = @import("../display.zig");
const callbacks = @import("callbacks.zig");

pub const Config = struct {
    /// A unique identifier of the widget to be used in `Tuile.findById` and `Widget.findById`.
    id: ?[]const u8 = null,

    /// `text` and `span` are mutually exclusive, only one of them must be defined.
    text: ?[]const u8 = null,

    /// `text` and `span` are mutually exclusive, only one of them must be defined.
    span: ?display.SpanView = null,

    /// See `Role`.
    role: Role = .checkbox,

    /// The initial state of the Checkbox.
    checked: bool = false,

    /// Checkbox will call this when its state changes.
    on_state_change: ?callbacks.Callback(bool) = null,

    /// Layout properties of the widget, see `LayoutProperties`.
    layout: LayoutProperties = .{},
};

pub const Role = enum {
    checkbox,
    radio,
};

pub const Checkbox = @This();

pub usingnamespace Widget.Leaf.Mixin(Checkbox);
pub usingnamespace Widget.Base.Mixin(Checkbox, .widget_base);

widget_base: Widget.Base,

role: Role,

view: *Label,

focus_handler: FocusHandler = .{},

checked: bool,

on_state_change: ?callbacks.Callback(bool),

pub fn create(config: Config) !*Checkbox {
    if (config.text == null and config.span == null) {
        @panic("text and span are mutually exclusive, only one of them must be defined");
    }

    var label: display.Span = undefined;
    if (config.text) |text| {
        label = try createDecoratedLabel(text);
    } else if (config.span) |span| {
        label = try createDecoratedLabel(span);
    }
    defer label.deinit();

    const view = try Label.create(.{ .span = label.view(), .layout = config.layout });

    const self = try internal.allocator.create(Checkbox);
    self.* = Checkbox{
        .widget_base = try Widget.Base.init(config.id),
        .view = view,
        .role = config.role,
        .checked = config.checked,
        .on_state_change = config.on_state_change,
    };
    return self;
}

pub fn destroy(self: *Checkbox) void {
    self.widget_base.deinit();
    self.view.destroy();
    internal.allocator.destroy(self);
}

pub fn widget(self: *Checkbox) Widget {
    return Widget.init(self);
}

pub fn setText(self: *Checkbox, text: []const u8) !void {
    const label = try createDecoratedLabel(text);
    defer label.deinit();
    self.view.setSpan(label.view());
}

pub fn setSpan(self: *Checkbox, span: display.SpanView) !void {
    const label = try createDecoratedLabel(span);
    defer label.deinit();
    self.view.setSpan(label.view());
}

pub fn render(self: *Checkbox, area: Rect, frame: Frame, theme: display.Theme) !void {
    frame.setStyle(area, .{ .bg = theme.interactive });
    self.focus_handler.render(area, frame, theme);

    if (self.view.content.getText().len < 4) {
        @panic("inner view must be at least 4 characters long for the bullet marker");
    }
    switch (self.role) {
        .checkbox => {
            std.mem.copyForwards(u8, self.view.content.text.items, "[ ] ");
            if (self.checked) {
                self.view.content.text.items[1] = 'x';
            }
        },
        .radio => {
            std.mem.copyForwards(u8, self.view.content.text.items, "( ) ");
            if (self.checked) {
                self.view.content.text.items[1] = '*';
            }
        },
    }

    try self.view.render(area, frame, theme);
}

pub fn layout(self: *Checkbox, constraints: Constraints) !Vec2 {
    return try self.view.layout(constraints);
}

pub fn handleEvent(self: *Checkbox, event: events.Event) !events.EventResult {
    if (self.focus_handler.handleEvent(event) == .consumed) {
        return .consumed;
    }
    switch (event) {
        .char => |char| switch (char) {
            ' ' => {
                self.checked = !self.checked;
                if (self.on_state_change) |on_state_change| {
                    on_state_change.call(self.checked);
                }
                return .consumed;
            },
            else => {},
        },
        else => {},
    }
    return .ignored;
}

pub fn layoutProps(self: *Checkbox) LayoutProperties {
    return self.view.layout_properties;
}

fn createDecoratedLabel(text: anytype) !display.Span {
    var label = display.Span.init(internal.allocator);
    errdefer label.deinit();
    try label.appendPlain("[ ] ");

    const TextT = @TypeOf(text);
    if (TextT == []const u8) {
        try label.appendPlain(text);
    } else if (TextT == display.SpanView) {
        try label.appendSpan(text);
    } else {
        @compileError("expected []const u8 or SpanView, got " ++ @typeName(TextT));
    }

    return label;
}
