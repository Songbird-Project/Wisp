const std = @import("std");
const types = @import("./types.zig");
const errors = @import("./error.zig");
const numbers = @import("numbers.zig");

pub fn lex(alloc: std.mem.Allocator, filename: [:0]const u8, src: [][]u8) !errors.Result(types.TokenIterator) {
    var token_list: std.ArrayList(types.Token) = .empty;

    for (src, 0..) |line, line_num| {
        var col: usize = 0;

        while (col < line.len) : (col += 1) {
            const char = line[col];
            var token: types.Token = .{};

            if (std.ascii.isWhitespace(char)) continue;
            if (std.mem.startsWith(u8, line[col..], "//")) break;

            if (std.ascii.isAlphabetic(char) or char == '_') {
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
            } else if (std.ascii.isDigit(char)) {
                var kind: numbers.NumberKind = .DecimalInt;

                const start = col;
                while (col < line.len) : (col += 1) {
                    if (std.ascii.isWhitespace(line[col])) break;
                    switch (line[col]) {
                        '+', '-', '*', '/', '%', '^' => break,
                        '.' => if (col + 1 < line.len) {
                            switch (line[col + 1]) {
                                '&', '|', '^', '<', '>', '!' => break,
                                else => {},
                            }
                        },
                        else => {},
                    }

                    if (col == start + 1 and line[start] == '0') {
                        switch (line[col]) {
                            'x' => kind = .HexInt,
                            'b' => kind = .BinaryInt,
                            else => {},
                        }

                        continue;
                    }

                    if (kind == .DecimalInt and numbers.char_kind[line[col]].decimal_point) kind = .DecimalFloat;
                    if (kind == .HexInt and numbers.char_kind[line[col]].decimal_point) kind = .HexFloat;
                    if (kind == .BinaryInt and numbers.char_kind[line[col]].decimal_point) kind = .BinaryFloat;

                    if (!numbers.validChar(kind, line[col])) return .{
                        .err = .{ .message = try errors.format(
                            alloc,
                            "invalid character in number",
                            filename,
                            line,
                            line[col .. col + 1],
                            line_num,
                            col,
                            col,
                        ), .code = 1 },
                    };
                }

                const underscore_error = numbers.validateUnderscores(line, start, col);
                if (underscore_error.len > 0) {
                    return .{
                        .err = .{ .message = try errors.format(
                            alloc,
                            underscore_error,
                            filename,
                            line,
                            null,
                            line_num,
                            start,
                            col,
                        ), .code = 1 },
                    };
                }

                col -= 1;
                token = .{
                    .kind = .Number,
                    .number_kind = kind,
                    .value = line[start .. col + 1],
                    .line_num = line_num,
                    .line_col = start,
                    .line_col_end = col,
                };
            } else if (isQuote(char)) {
                const quote = char;
                const start = col;

                col += 1;
                while (col < line.len) : (col += 1) {
                    if (line[col] == '\\' and col + 1 < line.len and isQuote(line[col + 1])) {
                        col += 1;
                        continue;
                    }

                    if (line[col] == quote) break;
                }

                if (col == line.len) {
                    return .{
                        .err = .{
                            .message = try errors.format(
                                alloc,
                                "expected closing quote",
                                filename,
                                line,
                                null,
                                line_num,
                                col,
                                col,
                            ),
                            .code = 1,
                        },
                    };
                }

                token = .{
                    .kind = .String,
                    .value = line[start + 1 .. col],
                    .line_num = line_num,
                    .line_col = start,
                    .line_col_end = col,
                };
            } else if (char == '.') {
                var kind: types.TokKind = .BAnd;
                const start = col;

                if (col + 1 < line.len) {
                    switch (line[col + 1]) {
                        '&' => kind = .BAnd,
                        '|' => kind = .BOr,
                        '^' => kind = .BXor,
                        '<' => kind = .BLeft,
                        '>' => kind = .BRight,
                        '!' => kind = .BNot,
                        else => return .{
                            .err = .{ .message = try errors.format(
                                alloc,
                                "unrecognized bitwise operator",
                                filename,
                                line,
                                line[start .. col + 2],
                                line_num,
                                start,
                                col + 2,
                            ), .code = 1 },
                        },
                    }
                }

                col += 2;
                token = .{
                    .kind = kind,
                    .value = line[start..col],
                    .line_num = line_num,
                    .line_col = start,
                    .line_col_end = col,
                };
            } else if (char == '?') {
                var kind: types.TokKind = .Question;
                const start = col;
                var len: usize = 0;

                if (col + 1 < line.len) {
                    var message: ?[]const u8 = null;

                    if (std.ascii.isAlphabetic(line[col + 1]) or line[col + 1] == '_') {
                        kind = .Question;
                    } else if (col + 2 < line.len and !std.ascii.isWhitespace(line[col + 1]) and !std.ascii.isWhitespace(line[col + 2])) {
                        len = 3;

                        if (std.mem.eql(u8, line[col + 1 .. col + 3], "<-")) {
                            kind = .LOptionalArrow;
                        } else if (std.mem.eql(u8, line[col + 1 .. col + 3], "<!")) {
                            kind = .LOptionalErrorArrow;
                        } else if (std.mem.eql(u8, line[col + 1 .. col + 3], "->")) {
                            kind = .ROptionalArrow;
                        } else if (std.mem.eql(u8, line[col + 1 .. col + 3], "!>")) {
                            kind = .ROptionalErrorArrow;
                        } else message = "unrecognized arrow operator";
                    } else return .{
                        .err = .{ .message = try errors.format(
                            alloc,
                            "unrecognized use of optional operator",
                            filename,
                            line,
                            null,
                            line_num,
                            col,
                            col,
                        ), .code = 1 },
                    };

                    if (message != null) {
                        return .{
                            .err = .{ .message = try errors.format(
                                alloc,
                                message.?,
                                filename,
                                line,
                                line[start .. col + 3],
                                line_num,
                                start,
                                col + 2,
                            ), .code = 1 },
                        };
                    }
                } else {
                    return .{
                        .err = .{ .message = try errors.format(
                            alloc,
                            "expected expression or arrow after `?`",
                            filename,
                            line,
                            null,
                            line_num,
                            col,
                            col,
                        ), .code = 1 },
                    };
                }

                col += len;
                token = .{
                    .kind = kind,
                    .value = line[start..col],
                    .line_num = line_num,
                    .line_col = start,
                    .line_col_end = col + 2,
                };
            } else if (char == '<') {
                var kind: types.TokKind = undefined;
                const start = col;

                if (col + 1 < line.len) {
                    if (line[col + 1] == '-') {
                        kind = .LArrow;
                    } else if (line[col + 1] == '!') {
                        kind = .LErrorArrow;
                    } else if (line[col + 1] == '=') {
                        kind = .LessOrEqual;
                    } else continue;
                } else {
                    return .{
                        .err = .{ .message = try errors.format(
                            alloc,
                            "expected expression or arrow tail after `<`",
                            filename,
                            line,
                            null,
                            line_num,
                            col,
                            col,
                        ), .code = 1 },
                    };
                }

                col += 2;
                token = .{
                    .kind = kind,
                    .value = line[start..col],
                    .line_num = line_num,
                    .line_col = start,
                    .line_col_end = col + 2,
                };
            } else if (char == '>') {
                var kind: types.TokKind = undefined;
                const start = col;

                if (col + 1 < line.len) {
                    if (line[col + 1] == '=') {
                        kind = .GreaterOrEqual;
                    } else continue;
                } else {
                    return .{
                        .err = .{ .message = try errors.format(
                            alloc,
                            "expected expression or `=` after `>`",
                            filename,
                            line,
                            null,
                            line_num,
                            col,
                            col,
                        ), .code = 1 },
                    };
                }

                col += 2;
                token = .{
                    .kind = kind,
                    .value = line[start..col],
                    .line_num = line_num,
                    .line_col = start,
                    .line_col_end = col + 2,
                };
            } else if (char == '=') {
                var kind: types.TokKind = undefined;
                const start = col;

                if (col + 1 < line.len) {
                    if (line[col + 1] == '=') {
                        kind = .EqualEqual;
                    } else continue;
                } else {
                    return .{
                        .err = .{ .message = try errors.format(
                            alloc,
                            "expected expression or `=` after `>`",
                            filename,
                            line,
                            null,
                            line_num,
                            col,
                            col,
                        ), .code = 1 },
                    };
                }

                col += 2;
                token = .{
                    .kind = kind,
                    .value = line[start..col],
                    .line_num = line_num,
                    .line_col = start,
                    .line_col_end = col + 2,
                };
            } else if (char == '-') {
                var kind: types.TokKind = undefined;
                const start = col;

                if (col + 1 < line.len) {
                    if (line[col + 1] == '>') {
                        kind = .RArrow;
                    }
                    if (line[col + 1] == '-') {
                        kind = .DashDash;
                    } else continue;
                } else {
                    return .{
                        .err = .{ .message = try errors.format(
                            alloc,
                            "expected expression or arrow head after `-`",
                            filename,
                            line,
                            null,
                            line_num,
                            col,
                            col,
                        ), .code = 1 },
                    };
                }

                col += 2;
                token = .{
                    .kind = kind,
                    .value = line[start..col],
                    .line_num = line_num,
                    .line_col = start,
                    .line_col_end = col + 2,
                };
            } else if (char == '!') {
                var kind: types.TokKind = undefined;
                const start = col;

                if (col + 1 < line.len) {
                    if (line[col + 1] == '>') {
                        kind = .RErrorArrow;
                    } else continue;
                } else {
                    return .{
                        .err = .{ .message = try errors.format(
                            alloc,
                            "expected expression or arrow head after `!`",
                            filename,
                            line,
                            null,
                            line_num,
                            col,
                            col,
                        ), .code = 1 },
                    };
                }

                col += 2;
                token = .{
                    .kind = kind,
                    .value = line[start..col],
                    .line_num = line_num,
                    .line_col = col,
                    .line_col_end = col + 2,
                };
            } else if (types.TokKind.charToKind(char)) |kind| {
                token = .{
                    .kind = kind,
                    .value = line[col .. col + 1],
                    .line_num = line_num,
                    .line_col = col,
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

fn isQuote(char: u8) bool {
    switch (char) {
        '\'', '"', '`' => return true,
        else => return false,
    }
}
