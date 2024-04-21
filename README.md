## Using the library:

Add dependency to your `build.zig.zon`:
```zig
.dependencies = .{
    .tuile = .{
        .url = "TODO",
        .hash = "..."
    },
},
```

and import it in `build.zig`:
```zig
const tuile = b.dependency("tuile", .{});
exe.root_module.addImport("tuile", tuile.module("tuile"));
exe.linkSystemLibrary("ncurses");
```
