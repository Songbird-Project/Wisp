const std = @import("std");
const types = @import("./types.zig");
const errors = @import("./error.zig");

pub fn lex(alloc: std.mem.Allocator, filename: [:0]const u8) !errors.Result(types.TokenIterator) {
    var token_list: std.ArrayList(types.Token) = .empty;
    const src = try readFile(alloc, filename);

    for (src, 0..) |line, line_num| {
        var col: usize = 0;
        if (line.len == 0 or line.len >= 2 and line[0] == '/' and line[1] == '/') continue;

        while (col < line.len) : (col += 1) {
            const char = line[col];
            var token: types.Token = .{};

            if (std.ascii.isWhitespace(char)) continue;

            if (types.TokKind.charToKind(char)) |kind| {
                token = .{
                    .kind = kind,
                    .value = &[_]u8{char},
                    .line_num = line_num,
                    .line_col = col,
                };
            } else if (std.ascii.isDigit(char)) {
                const start = col;
                while (col < line.len and std.ascii.isDigit(line[col])) : (col += 1) {}

                col -= 1;
                token = .{
                    .kind = .Number,
                    .value = line[start..col],
                    .line_num = line_num,
                    .line_col = col,
                };
            } else if (std.ascii.isAlphabetic(char) or char == '_') {
                const start = col;
                while (col < line.len and
                    (std.ascii.isAlphanumeric(line[col]) or line[col] == '_')) : (col += 1)
                {}

                col -= 1;
                token = .{
                    .kind = .Word,
                    .value = line[start..col],
                    .line_num = line_num,
                    .line_col = col,
                };
            } else {
                return .{
                    .err = .{ .message = try std.fmt.allocPrint(
                        alloc,
                        "unexpected character in file: {s}:{d}:{d} `{c}`\n",
                        .{
                            filename,
                            line_num,
                            col,
                            char,
                        },
                    ), .code = 1 },
                };
            }

            try token_list.append(alloc, token);
        }
    }

    return .{
        .ok = .{
            .tokens = try token_list.toOwnedSlice(alloc),
        },
    };
}

fn readFile(alloc: std.mem.Allocator, filename: [:0]const u8) ![][]u8 {
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
