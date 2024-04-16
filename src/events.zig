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
};

pub const Event = union(enum) {
    Char: u8,
    Key: Key,
    CtrlChar: u8,
    ShiftKey: Key,

    FocusIn,
    FocusOut,
};

pub const EventResult = enum {
    Ignored,
    Consumed,
};
