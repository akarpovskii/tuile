const std = @import("std");
const internal = @import("../internal.zig");
const Backend = @import("Backend.zig");
const Vec2 = @import("../Vec2.zig");
const events = @import("../events.zig");
const display = @import("../display.zig");
const render = @import("../render.zig");

// These structs must be identical to the ones in backends/crossterm/src/lib.rs
const RustVec2 = extern struct { x: c_uint, y: c_uint };

const RustKey = extern struct {
    key_type: RustKeyType,
    code: [4]u8,
    modifier: RustKeyModifiers,
};

const RustKeyModifiers = extern struct {
    shift: bool,
    control: bool,
    alt: bool,
};

const RustKeyType = enum(u16) {
    None,
    Char,
    Enter,
    Escape,
    Backspace,
    Tab,
    Left,
    Right,
    Up,
    Down,
    Insert,
    Delete,
    Home,
    End,
    PageUp,
    PageDown,
    F0,
    F1,
    F2,
    F3,
    F4,
    F5,
    F6,
    F7,
    F8,
    F9,
    F10,
    F11,
    F12,
    Resize,
};

const RustEffect = extern struct {
    highlight: bool = false,
    underline: bool = false,
    reverse: bool = false,
    blink: bool = false,
    dim: bool = false,
    bold: bool = false,
    italic: bool = false,
};

const RustColorPair = extern struct {
    fg: RustColor,
    bg: RustColor,
};

const RustColor = extern struct {
    tag: enum(u8) { dark, bright, ansi },
    data: extern union {
        dark: RustBaseColor,
        bright: RustBaseColor,
        ansi: u8,
    },
};

const RustBaseColor = enum(u8) {
    black,
    red,
    green,
    yellow,
    blue,
    magenta,
    cyan,
    white,
};

extern fn crossterm_init() void;
extern fn crossterm_deinit() void;
extern fn crossterm_poll_event() RustKey;
extern fn crossterm_refresh() void;
extern fn crossterm_print_at(pos: RustVec2, str: [*]const u8, n: c_uint) void;
extern fn crossterm_window_size() RustVec2;
extern fn crossterm_enable_effect(effect: RustEffect) void;
extern fn crossterm_disable_effect(effect: RustEffect) void;
extern fn crossterm_use_color(RustColorPair) void;

const Crossterm = @This();

pub fn create() !*Crossterm {
    crossterm_init();
    const self = try internal.allocator.create(Crossterm);
    self.* = .{};
    return self;
}

pub fn destroy(self: *Crossterm) void {
    crossterm_deinit();
    internal.allocator.destroy(self);
}

pub fn backend(self: *Crossterm) Backend {
    return Backend.init(self);
}

pub fn pollEvent(_: *Crossterm) !?events.Event {
    const key = crossterm_poll_event();
    return convertEvent(key);
}

pub fn refresh(_: *Crossterm) !void {
    crossterm_refresh();
}

pub fn printAt(_: *Crossterm, pos: Vec2, text: []const u8) !void {
    crossterm_print_at(.{ .x = @intCast(pos.x), .y = @intCast(pos.y) }, text.ptr, @intCast(text.len));
}

pub fn windowSize(_: *Crossterm) !Vec2 {
    const size = crossterm_window_size();
    return .{ .x = @intCast(size.x), .y = @intCast(size.y) };
}

pub fn enableEffect(_: *Crossterm, effect: display.Style.Effect) !void {
    var rust_effect: RustEffect = undefined;
    inline for (@typeInfo(display.Style.Effect).Struct.fields) |field| {
        @field(rust_effect, field.name) = @field(effect, field.name);
    }
    crossterm_enable_effect(rust_effect);
}

pub fn disableEffect(_: *Crossterm, effect: display.Style.Effect) !void {
    var rust_effect: RustEffect = undefined;
    inline for (@typeInfo(display.Style.Effect).Struct.fields) |field| {
        @field(rust_effect, field.name) = @field(effect, field.name);
    }
    crossterm_disable_effect(rust_effect);
}

pub fn useColor(_: *Crossterm, color_pair: display.ColorPair) !void {
    const rust_pair = RustColorPair{
        .fg = colorToRust(color_pair.fg),
        .bg = colorToRust(color_pair.bg),
    };
    crossterm_use_color(rust_pair);
}

fn colorToRust(color: display.Color) RustColor {
    switch (color) {
        .bright => |c| {
            return RustColor{
                .tag = .bright,
                .data = .{ .bright = @enumFromInt(@as(u8, @intCast(@intFromEnum(c)))) },
            };
        },
        .dark => |c| {
            return RustColor{
                .tag = .dark,
                .data = .{ .dark = @enumFromInt(@as(u8, @intCast(@intFromEnum(c)))) },
            };
        },
        .rgb => |rgb| {
            return RustColor{
                .tag = .ansi,
                .data = .{ .ansi = display.Palette256.findClosestNonSystem(rgb) },
            };
        },
    }
}

fn convertEvent(rust_key: RustKey) ?events.Event {
    const char_or_key = switch (rust_key.key_type) {
        .None => return null,
        .Char => blk: {
            const char: u32 = @bitCast(rust_key.code);
            break :blk events.Event{ .char = @intCast(char) };
        },
        .Enter => events.Event{ .key = .Enter },
        .Escape => events.Event{ .key = .Escape },
        .Backspace => events.Event{ .key = .Backspace },
        .Tab => events.Event{ .key = .Tab },
        .Left => events.Event{ .key = .Left },
        .Right => events.Event{ .key = .Right },
        .Up => events.Event{ .key = .Up },
        .Down => events.Event{ .key = .Down },
        .Insert => events.Event{ .key = .Insert },
        .Delete => events.Event{ .key = .Delete },
        .Home => events.Event{ .key = .Home },
        .End => events.Event{ .key = .End },
        .PageUp => events.Event{ .key = .PageUp },
        .PageDown => events.Event{ .key = .PageDown },
        .F0 => events.Event{ .key = .F0 },
        .F1 => events.Event{ .key = .F1 },
        .F2 => events.Event{ .key = .F2 },
        .F3 => events.Event{ .key = .F3 },
        .F4 => events.Event{ .key = .F4 },
        .F5 => events.Event{ .key = .F5 },
        .F6 => events.Event{ .key = .F6 },
        .F7 => events.Event{ .key = .F7 },
        .F8 => events.Event{ .key = .F8 },
        .F9 => events.Event{ .key = .F9 },
        .F10 => events.Event{ .key = .F10 },
        .F11 => events.Event{ .key = .F11 },
        .F12 => events.Event{ .key = .F12 },
        .Resize => events.Event{ .key = .Resize },
    };

    if (rust_key.modifier.control and char_or_key == .char) {
        return events.Event{ .ctrl_char = char_or_key.char };
    }
    if (rust_key.modifier.shift and char_or_key == .key) {
        return events.Event{ .shift_key = char_or_key.key };
    }
    return char_or_key;
}

pub fn requestMode(_: *Crossterm, mode: u32) !Backend.ReportMode {
    return Backend.requestModeTty(mode);
}
