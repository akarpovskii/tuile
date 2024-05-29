const std = @import("std");
const internal = @import("../internal.zig");
const Backend = @import("Backend.zig");
const Vec2 = @import("../Vec2.zig");
const events = @import("../events.zig");
const display = @import("../display.zig");

const c = @cImport({
    @cInclude("ncurses.h");
    @cInclude("locale.h");
});

const Ncurses = @This();

const NcursesErrors = error{ LocaleError, NcursesError };

scr: *c.struct__win_st,

has_colors: bool,

color_pairs: std.AutoHashMap(display.ColorPair, i16),

pub fn create() !*Ncurses {
    // Initialize the locale to get UTF-8 support, see `man ncurses` - Initialization
    if (c.setlocale(c.LC_ALL, "") == null) return error.LocaleError;

    const scr = c.initscr();
    if (c.raw() == c.ERR) return error.NcursesError;
    if (c.noecho() == c.ERR) return error.NcursesError;
    if (c.keypad(scr, true) == c.ERR) return error.NcursesError;

    var has_colors = false;
    if (c.has_colors()) {
        if (c.start_color() == c.ERR) return error.NcursesError;
        has_colors = true;
    }

    const Visibility = enum(c_int) {
        invisible = 0,
        visible = 1,
        very_visible = 2,
    };
    if (c.curs_set(@intFromEnum(Visibility.invisible)) == c.ERR) return error.NcursesError;

    c.timeout(0);

    const self = try internal.allocator.create(Ncurses);
    self.* = .{
        .scr = scr.?,
        .has_colors = has_colors,
        .color_pairs = std.AutoHashMap(display.ColorPair, i16).init(internal.allocator),
    };
    return self;
}

pub fn destroy(self: *Ncurses) void {
    defer internal.allocator.destroy(self);
    defer self.color_pairs.deinit();
    _ = c.endwin();
}

pub fn backend(self: *Ncurses) Backend {
    return Backend.init(self);
}

pub fn pollEvent(_: *Ncurses) !?events.Event {
    var ch = c.getch();
    if (ch == c.ERR) {
        return null;
    }

    var ctrl = false;
    if (ch >= 1 and ch <= 26 and ch != '\t' and ch != '\n') {
        ctrl = true;
        ch = 'a' + ch - 1;
        return .{ .ctrl_char = @intCast(ch) };
    }

    if (parseKey(ch)) |value| {
        return .{ .key = value };
    }

    switch (ch) {
        c.KEY_BTAB => return .{ .shift_key = .Tab },
        else => {},
    }

    var cp = std.mem.zeroes([4]u8);
    cp[0] = @intCast(ch);
    var i: usize = 1;
    while (!std.unicode.utf8ValidateSlice(&cp) and i < 4) {
        cp[i] = @intCast(c.getch());
        i += 1;
    }
    return .{ .char = try std.unicode.utf8Decode(cp[0..i]) };
}

fn parseKey(ch: c_int) ?events.Key {
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
        c.KEY_RESIZE => return .Resize,
        else => {},
    }
    return null;
}

pub fn refresh(_: *Ncurses) !void {
    if (c.refresh() == c.ERR) return error.NcursesError;
}

pub fn printAt(_: *Ncurses, pos: Vec2, text: []const u8) !void {
    _ = c.mvaddnstr(@intCast(pos.y), @intCast(pos.x), text.ptr, @intCast(text.len));
}

pub fn windowSize(self: *Ncurses) !Vec2 {
    _ = self;
    const x = c.getmaxx(c.stdscr);
    const y = c.getmaxy(c.stdscr);
    if (x == c.ERR or y == c.ERR) return error.NcursesError;
    return .{
        .x = @intCast(x),
        .y = @intCast(y),
    };
}

pub fn enableEffect(_: *Ncurses, effect: display.Style.Effect) !void {
    const attr = attrForEffect(effect);
    if (c.attron(attr) == c.ERR) return error.NcursesError;
}

pub fn disableEffect(_: *Ncurses, effect: display.Style.Effect) !void {
    const attr = attrForEffect(effect);
    if (c.attroff(attr) == c.ERR) return error.NcursesError;
}

fn attrForEffect(effect: display.Style.Effect) c_int {
    var attr = c.A_NORMAL;
    if (effect.highlight) attr |= c.A_STANDOUT;
    if (effect.underline) attr |= c.A_UNDERLINE;
    if (effect.reverse) attr |= c.A_REVERSE;
    if (effect.blink) attr |= c.A_BLINK;
    if (effect.dim) attr |= c.A_DIM;
    if (effect.bold) attr |= c.A_BOLD;
    if (effect.italic) attr |= c.A_ITALIC;
    return @bitCast(attr);
}

pub fn useColor(self: *Ncurses, color_pair: display.ColorPair) !void {
    if (!self.has_colors) {
        return;
    }
    const pair = try self.getOrInitColor(color_pair);
    if (c.attron(c.COLOR_PAIR(pair)) == c.ERR) return error.NcursesError;
}

fn getOrInitColor(self: *Ncurses, color_pair: display.ColorPair) !c_int {
    if (self.color_pairs.get(color_pair)) |pair| {
        return pair;
    }

    var pair: c_short = @intCast(self.color_pairs.count() + 1);
    if (c.COLOR_PAIRS <= pair) {
        var iter = self.color_pairs.iterator();
        const evict = iter.next().?;
        pair = @intCast(evict.value_ptr.*);
        _ = self.color_pairs.remove(evict.key_ptr.*);
    }

    const init_res = c.init_pair(
        @intCast(pair),
        colorToInt(color_pair.fg),
        colorToInt(color_pair.bg),
    );
    if (init_res == c.ERR) return error.NcursesError;
    try self.color_pairs.put(color_pair, pair);
    return pair;
}

fn colorToInt(color: display.Color) c_short {
    // Source - https://en.wikipedia.org/wiki/ANSI_escape_code#Colors
    const res = switch (color) {
        .dark => |base| switch (base) {
            .black => c.COLOR_BLACK,
            .red => c.COLOR_RED,
            .green => c.COLOR_GREEN,
            .yellow => c.COLOR_YELLOW,
            .blue => c.COLOR_BLUE,
            .magenta => c.COLOR_MAGENTA,
            .cyan => c.COLOR_CYAN,
            .white => c.COLOR_WHITE,
        },
        .bright => |base| switch (base) {
            .black => @rem(8 + c.COLOR_BLACK, c.COLORS),
            .red => @rem(8 + c.COLOR_RED, c.COLORS),
            .green => @rem(8 + c.COLOR_GREEN, c.COLORS),
            .yellow => @rem(8 + c.COLOR_YELLOW, c.COLORS),
            .blue => @rem(8 + c.COLOR_BLUE, c.COLORS),
            .magenta => @rem(8 + c.COLOR_MAGENTA, c.COLORS),
            .cyan => @rem(8 + c.COLOR_CYAN, c.COLORS),
            .white => @rem(8 + c.COLOR_WHITE, c.COLORS),
        },
        .rgb => |rgb| if (c.COLORS >= 256)
            display.Palette256.findClosestNonSystem(rgb)
        else
            display.Palette256.findClosestSystem(rgb),
    };

    return @intCast(res);
}
