<a name="page-top"></a>

# Supported Backends

<details>
  <summary>Table of Contents</summary>
  <ol>
    <li><a href="#selecting-a-backend">Selecting a Backend</a></li>
    <li><a href="#crossterm">Crossterm</a></li>
    <li><a href="#ncurses">Ncurses</a></li>
  </ol>
</details>

## Selecting a Backend

Tuile is configured to use a [prebuilt](https://github.com/akarpovskii/tuile-crossterm) version of `crossterm` backend by default.

To select another backend, pass an option to `Build.dependency` in `build.zig`:

```zig
const tuile = b.dependency("tuile", .{ .backend = <backend name> })
```

## Crossterm

[Crossterm](https://github.com/crossterm-rs/crossterm) is a pure-rust, terminal manipulation library. It supports all UNIX and Windows terminals down to Windows 7 (not all terminals are tested, see Crossterm's [Tested Terminals](https://github.com/crossterm-rs/crossterm?tab=readme-ov-file#tested-terminals) for more info).

By default, Tuile fetches a prebuilt version of the backend from [tuile-crossterm](https://github.com/akarpovskii/tuile-crossterm/releases). If you want Tuile to build it from source, set `prebuilt` to `false`:

```zig
const tuile = b.dependency("tuile", .{ .prebuilt = false })
```

Tuile uses Crossterm v0.27 which has a minimum requirement of Rust v1.58. Follow [here](https://www.rust-lang.org/tools/install) to download and install Rust.

### A word on Windows
By default Rust targets MSVC toolchain on Windows which makes it difficult to link from Zig. For that reason, tuile-crossterm compiles Rust with gnu ABI and does some (albeit small) crimes during linking. See [`build.crab`](https://github.com/akarpovskii/build.crab?tab=readme-ov-file#windows) description if you want to know more.

Nevertheless, Tuile is designed to be plug and play, and you should be able to just use it without worrying too much about what happens internally. If you face any problems, please submit a [bug report](https://github.com/akarpovskii/tuile/issues/new?labels=bug&template=bug-report.md).

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Ncurses

To be able to use `ncurses` backend, [ncurses](https://invisible-island.net/ncurses/) must be installed and available as system library.

Tuile was tested with ncurses 5.7, but other versions should work regardless.

* macOS

    A version of ncurses should already be installed in your system (or is it shipped with XCode and the command line tools?), so you don't have to do anything.

* Linux

    ```sh
    sudo apt-get install libncurses5-dev libncursesw5-dev
    ```

* Windows

    Prebuilt binaries are available on the [official website](https://invisible-island.net/ncurses/#download_mingw).

<p align="right">(<a href="#readme-top">back to top</a>)</p>
