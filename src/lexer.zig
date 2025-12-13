const std = @import("std");
const types = @import("./types.zig");
const errors = @import("./error.zig");

pub fn lex(alloc: std.mem.Allocator, filename: [:0]const u8, src: [][]u8) !errors.Result(types.TokenIterator) {
    var token_list: std.ArrayList(types.Token) = .empty;

    for (src, 0..) |line, line_num| {
        var col: usize = 0;

        while (col < line.len) : (col += 1) {
            const char = line[col];
            var token: types.Token = .{};

            if (std.ascii.isWhitespace(char)) continue;
            if (std.mem.startsWith(u8, line[col..], "//")) break;

            if (types.TokKind.charToKind(char)) |kind| {
                token = .{
                    .kind = kind,
                    .value = line[col .. col + 1],
                    .line_num = line_num,
                    .line_col = col,
                    .line_col_end = col,
                };
            } else if (std.ascii.isDigit(char)) {
                const start = col;
                while (col < line.len and std.ascii.isDigit(line[col])) : (col += 1) {}

                col -= 1;
                token = .{
                    .kind = .Number,
                    .value = line[start .. col + 1],
                    .line_num = line_num,
                    .line_col = start,
                    .line_col_end = col,
                };
            } else if (std.ascii.isAlphabetic(char) or char == '_') {
                const start = col;
                while (col < line.len and
                    (std.ascii.isAlphanumeric(line[col]) or line[col] == '_')) : (col += 1)
                {}

                col -= 1;
                token = .{
                    .kind = .Word,
                    .value = line[start .. col + 1],
                    .line_num = line_num,
                    .line_col = start,
                    .line_col_end = col,
                };
            } else {
                return .{
                    .err = .{ .message = try errors.format(
                        alloc,
                        "unexpected character in file",
                        filename,
                        line,
                        line[col .. col + 1],
                        line_num,
                        col,
                        col,
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

pub fn readFile(alloc: std.mem.Allocator, filename: [:0]const u8) ![][]u8 {
    var file = try std.fs.cwd().openFile(filename, .{ .mode = .read_only });
    defer file.close();

    var read_buf: [2048]u8 = undefined;
    var file_reader: std.fs.File.Reader = file.reader(&read_buf);
    const reader = &file_reader.interface;

    var lines: std.ArrayList([]u8) = .empty;
    var line = std.io.Writer.Allocating.init(alloc);

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
