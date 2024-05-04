use core::slice;
use std::{ffi::c_uint, io::Write, time::Duration};

use crossterm::{cursor, event, execute, queue, style::{Attribute, Attributes, Print, SetAttributes, SetBackgroundColor, SetForegroundColor}, terminal::{self, disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen}};

// These structs must be identical to the ones in backends/Crossterm.zig
#[repr(C)]
pub struct Vec2 {
    x: c_uint,
    y: c_uint,
}

#[repr(C)]
pub struct Key {
    key_type: KeyType,
    code: [u8;4],
    modifiers: KeyModifiers,
}

#[repr(C)]
pub struct KeyModifiers {
    shift: bool,
    control: bool,
    alt: bool,
}

#[repr(u16)]
pub enum KeyType {
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
}

#[repr(C)]
pub struct ColorPair {
    fg: Color,
    bg: Color,
}

#[repr(C)]
pub struct Color {
    tag: ColorTag,
    data: ColorData,
}

#[repr(u8)]
pub enum ColorTag {
    Dark,
    Bright,
    Ansi,
}

#[repr(C)]
pub union ColorData {
    dark: BaseColor,
    bright: BaseColor,
    ansi: u8,
}

#[repr(u8)]
#[derive(Clone, Copy)]
pub enum BaseColor {
    Black,
    Red,
    Green,
    Yellow,
    Blue,
    Magenta,
    Cyan,
    White,
}

#[no_mangle]
pub extern "C" fn crossterm_init() {
    enable_raw_mode().unwrap();
    execute!(
        std::io::stdout(),
        EnterAlternateScreen,
        cursor::Hide
    ).unwrap();

}

#[no_mangle]
pub extern "C" fn crossterm_deinit() {
    execute!(
        std::io::stdout(),
        SetForegroundColor(crossterm::style::Color::Reset),
        SetBackgroundColor(crossterm::style::Color::Reset),
        LeaveAlternateScreen,
        cursor::Show,
        cursor::MoveTo(0, 0),
        terminal::Clear(terminal::ClearType::All)
    ).unwrap();
    disable_raw_mode().unwrap();
}

#[no_mangle]
pub extern "C" fn crossterm_poll_event() -> Key {
    if event::poll(Duration::from_secs(0)).unwrap() {
        let event = event::read().unwrap();
        match event {
            event::Event::Key(event) => match event.kind {
                event::KeyEventKind::Press => event.into(),
                _ => Default::default()
            },
            event::Event::Resize(_, _) => {
                // TODO: Make it a sepearate method and call in Tuile.handleResize?
                queue!(
                    std::io::stdout(),
                    terminal::Clear(terminal::ClearType::All)
                ).unwrap();

                Key {
                    key_type: KeyType::Resize,
                    ..Default::default()
                }
            },
            _ => Default::default(),
        }
    } else {
        Default::default()
    }
}

#[no_mangle]
pub extern "C" fn crossterm_refresh() {
    std::io::stdout().flush().unwrap();
}

#[no_mangle]
pub extern "C" fn crossterm_print_at(pos: Vec2, str: *const u8, n: c_uint) {
    let text = unsafe {
        let slice = slice::from_raw_parts(str, n as usize);
        std::str::from_utf8_unchecked(slice)
    };
    queue!(
        std::io::stdout(),
        cursor::MoveTo(pos.x as u16, pos.y as u16),
        Print(text)
    ).unwrap();
}

#[repr(C)]
pub struct Effect {
    highlight: bool,
    underline: bool,
    reverse: bool,
    blink: bool,
    dim: bool,
    bold: bool,
    italic: bool,
}

#[no_mangle]
pub extern "C" fn crossterm_window_size() -> Vec2 {
    let size = terminal::size().unwrap_or((1, 1));
    Vec2{ x: size.0 as c_uint, y: size.1 as c_uint}
}

#[no_mangle]
pub extern "C" fn crossterm_enable_effect(effect: Effect) {
    let mut attrs: Attributes = Attribute::Reset.into();
    if effect.highlight { attrs.set(Attribute::Reverse); }
    if effect.underline { attrs.set(Attribute::Underlined); }
    if effect.reverse { attrs.set(Attribute::Reverse); }
    if effect.blink { attrs.set(Attribute::SlowBlink); }
    if effect.dim { attrs.set(Attribute::Dim); }
    if effect.bold { attrs.set(Attribute::Bold); }
    if effect.italic { attrs.set(Attribute::Italic); }

    queue!(std::io::stdout(), SetAttributes(attrs)).unwrap();
}

#[no_mangle]
pub extern "C" fn crossterm_disable_effect(effect: Effect) {
    let mut attrs: Attributes = Attribute::Reset.into();
    if effect.highlight { attrs.set(Attribute::NoReverse); }
    if effect.underline { attrs.set(Attribute::NoUnderline); }
    if effect.reverse { attrs.set(Attribute::NoReverse); }
    if effect.blink { attrs.set(Attribute::NoBlink); }
    if effect.dim { attrs.set(Attribute::NormalIntensity); }
    if effect.bold { attrs.set(Attribute::NormalIntensity); }
    if effect.italic { attrs.set(Attribute::NoItalic); }

    queue!(std::io::stdout(), SetAttributes(attrs)).unwrap();
}

#[no_mangle]
pub extern "C" fn crossterm_use_color(color: ColorPair) {
    let fg = color.fg.into();
    let bg = color.bg.into();
    queue!(
        std::io::stdout(),
        SetBackgroundColor(fg),
        SetBackgroundColor(bg),
    ).unwrap();
}

impl Default for Key {
    fn default() -> Self {
        Self {
            key_type: Default::default(),
            code: Default::default(),
            modifiers: Default::default()
        }
    }
}

impl Default for KeyModifiers {
    fn default() -> Self {
        Self { shift: false, control: false, alt: false }
    }
}

impl Default for KeyType {
    fn default() -> Self {
        KeyType::None
    }
}

impl From<event::KeyEvent> for Key {
    fn from(value: event::KeyEvent) -> Self {
        let modifiers = KeyModifiers {
            shift: value.modifiers.bits() & event::KeyModifiers::SHIFT.bits() != 0,
            control: value.modifiers.bits() & event::KeyModifiers::CONTROL.bits() != 0,
            alt: value.modifiers.bits() & event::KeyModifiers::ALT.bits() != 0,
        };
        let (key_type, code) = match value.code {
            event::KeyCode::Backspace => (KeyType::Backspace, Default::default()),
            event::KeyCode::Enter => (KeyType::Enter, Default::default()),
            event::KeyCode::Left => (KeyType::Left, Default::default()),
            event::KeyCode::Right => (KeyType::Right, Default::default()),
            event::KeyCode::Up => (KeyType::Up, Default::default()),
            event::KeyCode::Down => (KeyType::Down, Default::default()),
            event::KeyCode::Home => (KeyType::Home, Default::default()),
            event::KeyCode::End => (KeyType::End, Default::default()),
            event::KeyCode::PageUp => (KeyType::PageUp, Default::default()),
            event::KeyCode::PageDown => (KeyType::PageDown, Default::default()),
            event::KeyCode::Tab => (KeyType::Tab, Default::default()),
            event::KeyCode::BackTab => return Key {
                key_type: KeyType::Tab,
                modifiers: KeyModifiers { shift: true, ..Default::default() },
                ..Default::default()
            },
            event::KeyCode::Delete => (KeyType::Delete, Default::default()),
            event::KeyCode::Insert => (KeyType::Insert, Default::default()),
            event::KeyCode::F(n) => match n {
                0 => (KeyType::F0, Default::default()),
                1 => (KeyType::F1, Default::default()),
                2 => (KeyType::F2, Default::default()),
                3 => (KeyType::F3, Default::default()),
                4 => (KeyType::F4, Default::default()),
                5 => (KeyType::F5, Default::default()),
                6 => (KeyType::F6, Default::default()),
                7 => (KeyType::F7, Default::default()),
                8 => (KeyType::F8, Default::default()),
                9 => (KeyType::F9, Default::default()),
                10 => (KeyType::F10, Default::default()),
                11 => (KeyType::F10, Default::default()),
                12 => (KeyType::F12, Default::default()),
                _ => todo!(),
            },
            event::KeyCode::Char(char) => (KeyType::Char, u32::to_ne_bytes(char.into())),
            event::KeyCode::Null => return Default::default(),
            event::KeyCode::Esc => (KeyType::Escape, Default::default()),
            _ => return Default::default(),
        };

        Key {
            modifiers,
            key_type,
            code
        }
    }
}

impl From<Color> for crossterm::style::Color {
    fn from(value: Color) -> Self {
        match value.tag {
            ColorTag::Dark => {
                let color = unsafe { value.data.dark };
                match color {
                    BaseColor::Black => crossterm::style::Color::Black,
                    BaseColor::Red => crossterm::style::Color::DarkRed,
                    BaseColor::Green => crossterm::style::Color::DarkGreen,
                    BaseColor::Yellow => crossterm::style::Color::DarkYellow,
                    BaseColor::Blue => crossterm::style::Color::DarkBlue,
                    BaseColor::Magenta => crossterm::style::Color::DarkMagenta,
                    BaseColor::Cyan => crossterm::style::Color::DarkCyan,
                    BaseColor::White => crossterm::style::Color::Grey,
                }
            },
            ColorTag::Bright => {
                let color = unsafe { value.data.bright };
                match color {
                    BaseColor::Black => crossterm::style::Color::DarkGrey,
                    BaseColor::Red => crossterm::style::Color::Red,
                    BaseColor::Green => crossterm::style::Color::Green,
                    BaseColor::Yellow => crossterm::style::Color::Yellow,
                    BaseColor::Blue => crossterm::style::Color::Blue,
                    BaseColor::Magenta => crossterm::style::Color::Magenta,
                    BaseColor::Cyan => crossterm::style::Color::Cyan,
                    BaseColor::White => crossterm::style::Color::White,
                }
            },
            ColorTag::Ansi => {
                let color = unsafe { value.data.ansi };
                crossterm::style::Color::AnsiValue(color)
            },
        }
    }
}