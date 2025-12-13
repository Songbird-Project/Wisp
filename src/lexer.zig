const std = @import("std");
const types = @import("types");

pub fn lex(filename: [:0]const u8, alloc: std.mem.Allocator) !types.Result(types.TokenIterator) {
    var tokenList: std.ArrayList(types.Token) = .empty;
    const src = try readFile(filename, alloc);

    for (src, 0..) |line, lineNum| {
        for (line, 0..) |char, lineCol| {
            var token: types.Token = .{};

            if (types.TokKind.charToKind(char)) |kind| {
                token.kind = kind;
            } else {
                return .{
                    .err = .{ .message = try std.fmt.allocPrint(
                        alloc,
                        "Unexpected character in file: {s}:{d}:{d} `{c}`\n",
                        .{
                            filename,
                            lineNum,
                            lineCol,
                            char,
                        },
                    ), .code = 1 },
                };
            }

            try tokenList.append(alloc, token);
        }
    }

    return .{
        .ok = .{
            .tokens = try tokenList.toOwnedSlice(alloc),
        },
    };
}

fn readFile(filename: [:0]const u8, alloc: std.mem.Allocator) ![][]u8 {
    var file = try std.fs.cwd().openFile(filename, .{ .mode = .read_only });
    defer file.close();

    var read_buf: [2048]u8 = undefined;
    var file_reader: std.fs.File.Reader = file.reader(&read_buf);
    const reader = &file_reader.interface;

    var lines: std.ArrayList([]u8) = .empty;
    var line_writer = std.io.Writer.Allocating.init(alloc);
    var line: []const u8 = undefined;

    while (true) {
        _ = reader.streamDelimiter(&line_writer.writer, '\n') catch |err| {
            if (err == error.EndOfStream) break else return err;
        };
        _ = reader.toss(1);

        line = std.mem.trim(u8, line_writer.written(), " \t\r\n");

        const line_copy = try alloc.dupe(u8, line);
        try lines.append(alloc, line_copy);
        line_writer.clearRetainingCapacity();
    }

    if (line.len > 0) {
        const line_copy = try alloc.dupe(u8, line);
        try lines.append(alloc, line_copy);
    }

    return lines.toOwnedSlice(alloc);
}
