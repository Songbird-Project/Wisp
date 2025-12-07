const std = @import("std");
const types = @import("./types.zig");

pub fn Parse(alloc: std.mem.Allocator) !types.astNode {
    var root: types.astNode = .{
        .kind = types.astType.Root,
    };

    const children = try alloc.create(std.ArrayList(types.astNode));
    children.* = std.ArrayList(types.astNode).empty;
    root.children = children;

    const lines = try ReadFile(alloc);
    defer {
        for (lines) |line| {
            alloc.free(line);
        }
        alloc.free(lines);
    }

    for (lines) |line| {
        if (line.len == 0 or line.len >= 2 and std.mem.startsWith(u8, line, "//")) continue;

        var tokList: std.ArrayList([]const u8) = .empty;
        defer tokList.deinit(alloc);

        var tokIter = std.mem.tokenizeAny(u8, line, " \t\r\n");
        while (tokIter.next()) |tok| {
            try tokList.append(alloc, tok);
        }

        const toks = tokList.items;
        if (toks.len == 0) continue;

        var child: types.astNode = .{};

        if (std.mem.eql(u8, toks[0], "fn")) {
            child.kind = types.astType.Function;

            std.debug.print("function", .{});
        }

        try root.children.?.append(alloc, child);
    }

    return root;
}

fn ReadFile(alloc: std.mem.Allocator) ![][]u8 {
    var argv = try std.process.argsWithAllocator(alloc);
    defer argv.deinit();
    _ = argv.next();
    const filename = if (argv.next()) |a| std.mem.sliceTo(a, 0) else "main.wp";

    var file = try std.fs.cwd().openFile(filename, .{ .mode = .read_only });
    defer file.close();

    var read_buf: [2048]u8 = undefined;
    var file_reader: std.fs.File.Reader = file.reader(&read_buf);
    const reader = &file_reader.interface;

    var lines: std.ArrayList([]u8) = .empty;
    errdefer {
        for (lines.items) |line| {
            alloc.free(line);
        }
        lines.deinit(alloc);
    }

    var line = std.Io.Writer.Allocating.init(alloc);
    defer line.deinit();

    while (true) {
        _ = reader.streamDelimiter(&line.writer, '\n') catch |err| {
            if (err == error.EndOfStream) break else return err;
        };
        _ = reader.toss(1);

        const line_copy = try alloc.dupe(u8, line.written());
        try lines.append(alloc, line_copy);
        line.clearRetainingCapacity();
    }

    if (line.written().len > 0) {
        const line_copy = try alloc.dupe(u8, line.written());
        try lines.append(alloc, line_copy);
    }

    return lines.toOwnedSlice(alloc);
}
