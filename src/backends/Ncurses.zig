const std = @import("std");
const Backend = @import("Backend.zig");
const Vec2 = @import("../Vec2.zig");
const events = @import("../events.zig");
const Style = @import("../Style.zig");

const c = @cImport({
    @cInclude("ncurses.h");
    @cInclude("locale.h");
});

const Ncurses = @This();

const NcursesError = error{ LocaleError, GeneralError };

scr: *c.struct__win_st,

pub fn init() !Ncurses {
    // Initialize the locale to get UTF-8 support, see `man ncurses` - Initialization
    if (c.setlocale(c.LC_ALL, "") == null) return error.LocaleError;

    const scr = c.initscr();
    if (c.raw() == c.ERR) return error.GeneralError;
    if (c.noecho() == c.ERR) return error.GeneralError;
    if (c.keypad(scr, true) == c.ERR) return error.GeneralError;

    const Visibility = enum(c_int) {
        Invisible = 0,
        Visible = 1,
        VeryVisible = 2,
    };
    if (c.curs_set(@intFromEnum(Visibility.Invisible)) == c.ERR) return error.GeneralError;
    c.timeout(0);
    return .{
        .scr = scr.?,
    };
}

pub fn deinit(_: *Ncurses) !void {
    if (c.endwin() == c.ERR) return error.GeneralError;
}

pub fn backend(self: *Ncurses) Backend {
    return Backend.init(self);
}

pub fn poll_event(_: *Ncurses) !?events.Event {
    var ch = c.getch();
    if (ch == c.ERR) {
        return null;
    }

    var ctrl = false;
    if (ch >= 1 and ch <= 26 and ch != '\t' and ch != '\n') {
        ctrl = true;
        ch = 'a' + ch - 1;
        return .{ .CtrlChar = @intCast(ch) };
    }

    if (parse_key(ch)) |value| {
        return .{ .Key = value };
    }

    switch (ch) {
        c.KEY_BTAB => return .{ .ShiftKey = .Tab },
        else => {},
    }

    return .{ .Char = @intCast(ch) };
}

fn parse_key(ch: c_int) ?events.Key {
    switch (ch) {
        @as(c_int, '\t') => return .Tab,
        @as(c_int, '\n') => return .Enter,
        c.KEY_ENTER => return .Enter,
        27 => return .Escape,
        127 => return .Backspace,
        c.KEY_BACKSPACE => return .Backspace,
        c.KEY_LEFT => return .Left,
        c.KEY_RIGHT => return .Right,
        c.KEY_UP => return .Up,
        c.KEY_DOWN => return .Down,
        c.KEY_IC => return .Insert,
        c.KEY_DC => return .Delete,
        c.KEY_HOME => return .Home,
        c.KEY_END => return .End,
        c.KEY_PPAGE => return .PageUp,
        c.KEY_NPAGE => return .PageDown,
        c.KEY_F(0) => return .F0,
        c.KEY_F(1) => return .F1,
        c.KEY_F(2) => return .F2,
        c.KEY_F(3) => return .F3,
        c.KEY_F(4) => return .F4,
        c.KEY_F(5) => return .F5,
        c.KEY_F(6) => return .F6,
        c.KEY_F(7) => return .F7,
        c.KEY_F(8) => return .F8,
        c.KEY_F(9) => return .F9,
        c.KEY_F(10) => return .F10,
        c.KEY_F(11) => return .F11,
        c.KEY_F(12) => return .F12,
        else => {},
    }
    return null;
}

pub fn refresh(_: *Ncurses) !void {
    if (c.refresh() == c.ERR) return error.GeneralError;
}

pub fn print_at(_: *Ncurses, pos: Vec2, text: []const u8) !void {
    _ = c.mvaddnstr(@intCast(pos.y), @intCast(pos.x), text.ptr, @intCast(text.len));
}

pub fn window_size(self: *Ncurses) !Vec2 {
    _ = self;
    const x = c.getmaxx(c.stdscr);
    const y = c.getmaxy(c.stdscr);
    if (x == c.ERR or y == c.ERR) return error.GeneralError;
    return .{
        .x = @intCast(x),
        .y = @intCast(y),
    };
}

pub fn enable_effect(_: *Ncurses, effect: Style.Effect) !void {
    const attr = attr_for_effect(effect);
    if (c.attron(attr) == c.ERR) return error.GeneralError;
}

pub fn disable_effect(_: *Ncurses, effect: Style.Effect) !void {
    const attr = attr_for_effect(effect);
    if (c.attroff(attr) == c.ERR) return error.GeneralError;
}

fn attr_for_effect(effect: Style.Effect) c_int {
    return switch (effect) {
        .None => c.A_NORMAL,
        .Highlight => c.A_STANDOUT,
        .Underline => c.A_UNDERLINE,
        .Reverse => c.A_REVERSE,
        .Blink => c.A_BLINK,
        .Dim => c.A_DIM,
        .Bold => c.A_BOLD,
    };
}
