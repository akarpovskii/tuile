pub const Key = enum {
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

pub const FocusDirection = enum { front, back };

pub const Event = union(enum) {
    char: u21,
    key: Key,
    ctrl_char: u21,
    shift_key: Key,

    focus_in: FocusDirection,
    focus_out,
};

pub const EventResult = enum {
    ignored,
    consumed,
};
