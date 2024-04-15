const std = @import("std");

pub fn load(allocator: std.mem.Allocator) !std.process.EnvMap {
    const cwd = std.fs.cwd();
    const file = try cwd.openFile(".env", .{ .mode = std.fs.File.OpenMode.read_only });
    defer file.close();

    const vars = try readVariables(file, allocator);
    defer {
        for (vars) |v| {
            allocator.free(v.name);
            allocator.free(v.value);
        }
        allocator.free(vars);
    }

    var env = try std.process.getEnvMap(allocator);
    for (vars) |v| {
        try env.put(v.name, v.value);
    }
    return env;
}

const EnvVar = struct { name: []u8, value: []u8 };

fn readVariables(file: std.fs.File, allocator: std.mem.Allocator) ![]EnvVar {
    var buf_reader = std.io.bufferedReader(file.reader());
    const reader = buf_reader.reader();

    var line = std.ArrayList(u8).init(allocator);
    defer line.deinit();

    const writer = line.writer();
    var result = std.ArrayList(EnvVar).init(allocator);

    while (reader.streamUntilDelimiter(writer, '\n', null)) {
        defer line.clearRetainingCapacity();

        const v = try readVariable(&line, allocator);
        if (v) |value| try result.append(value);
    } else |err| switch (err) {
        error.EndOfStream => {
            const v = try readVariable(&line, allocator);
            if (v) |value| try result.append(value);
        },
        else => return err,
    }

    return result.toOwnedSlice();
}

fn readVariable(line: *std.ArrayList(u8), allocator: std.mem.Allocator) !?EnvVar {
    if (line.getLast() == '\r') {
        _ = line.*.popOrNull();
    }

    if (line.items.len == 0) {
        return null;
    }

    const eq = std.mem.indexOf(u8, line.items, "=");
    if (eq) |idx| {
        var name = std.ArrayList(u8).init(allocator);
        try name.appendSlice(line.items[0..idx]);
        var value = std.ArrayList(u8).init(allocator);
        try value.appendSlice(line.items[idx + 1 ..]);
        return .{ .name = try name.toOwnedSlice(), .value = try value.toOwnedSlice() };
    } else {
        return .{ .name = try line.toOwnedSlice(), .value = "" };
    }
}
