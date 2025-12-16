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

                    if (!numbers.validChar(kind, line[col])) {
                        if (std.ascii.isAlphanumeric(line[col])) {
                            return .{
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
                        } else break;
                    }
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

                var found_quote = false;
                col += 1;
                while (col < line.len) : (col += 1) {
                    if (line[col] == '\\' and col + 1 < line.len and isQuote(line[col + 1])) {
                        col += 1;
                        continue;
                    }

                    if (line[col] == quote) {
                        found_quote = true;
                        break;
                    }
                }

                if (!found_quote) {
                    return .{
                        .err = .{
                            .message = try errors.format(
                                alloc,
                                "expected closing quote",
                                filename,
                                line,
                                null,
                                line_num,
                                start,
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
            } else {
                const op = parseOp(line, col);
                const start = col;

                switch (op) {
                    .err => |err| return .{
                        .err = .{ .message = try errors.format(
                            alloc,
                            err.message,
                            filename,
                            line,
                            line[start .. col + 1],
                            line_num,
                            start,
                            col,
                        ), .code = err.code },
                    },
                    .ok => {},
                }

                col += op.ok.length;
                token = .{
                    .kind = op.ok.kind,
                    .value = line[start .. col + 1],
                    .line_num = line_num,
                    .line_col = start,
                    .line_col_end = col,
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

fn parseOp(line: []const u8, col: usize) errors.Result(struct {
    kind: types.TokKind,
    length: usize,
}) {
    const char = line[col];
    var len: usize = 0;
    var message: ?[]const u8 = null;
    var kind: types.TokKind = types.TokKind.charToKind(char) orelse return .{ .err = .{
        .message = "unexpected character in file",
        .code = 1,
    } };

    if (char == '?' and col + 2 < line.len) {
        const arrow = line[col + 1 .. col + 3];

        if (std.ascii.isAlphanumeric(line[col + 1]) or line[col + 1] == '_') {
            kind = .Question;
        } else if (col + 2 < line.len and !std.ascii.isWhitespace(line[col + 1]) and !std.ascii.isWhitespace(line[col + 2])) {
            len = 2;

            if (std.mem.eql(u8, arrow, "<-")) {
                kind = .LOptionalArrow;
            } else if (std.mem.eql(u8, arrow, "<!")) {
                kind = .LOptionalErrorArrow;
            } else if (std.mem.eql(u8, arrow, "->")) {
                kind = .ROptionalArrow;
            } else if (std.mem.eql(u8, arrow, "!>")) {
                kind = .ROptionalErrorArrow;
            } else message = "unrecognized arrow operator";
        }
    } else if (col + 1 < line.len) {
        const op = line[col .. col + 2];

        if (char == '.') {
            len = 1;

            switch (line[col + 1]) {
                '&' => kind = .BAnd,
                '|' => kind = .BOr,
                '^' => kind = .BXor,
                '<' => kind = .BLeft,
                '>' => kind = .BRight,
                '!' => kind = .BNot,
                else => message = "unrecognized bitwise operator",
            }
        } else if (line[col + 1] == '=') {
            len = 1;

            switch (char) {
                '<' => kind = .LessOrEqual,
                '>' => kind = .GreaterOrEqual,
                '=' => kind = .EqualEqual,
                '!' => kind = .BangEqual,
                ':' => kind = .ColonEqual,
                '#' => kind = .HashEqual,
                else => {},
            }
        } else if (line[col + 1] == '>') {
            len = 1;

            switch (char) {
                '-' => kind = .RArrow,
                '!' => kind = .RErrorArrow,
                else => {},
            }
        } else if (char == '<') {
            len = 1;

            switch (line[col + 1]) {
                '-' => kind = .LArrow,
                '!' => kind = .LErrorArrow,
                else => {},
            }
        } else if (std.mem.eql(u8, op, "++")) {
            len = 1;
            kind = .PlusPlus;
        } else if (std.mem.eql(u8, op, "--")) {
            len = 1;
            kind = .DashDash;
        } else if (std.mem.eql(u8, op, "::")) {
            len = 1;
            kind = .ColonColon;
        }
    }

    if (message != null) return .{
        .err = .{
            .message = message.?,
            .code = 1,
        },
    } else return .{
        .ok = .{
            .kind = kind,
            .length = len,
        },
    };
}

fn isQuote(char: u8) bool {
    switch (char) {
        '\'', '"', '`' => return true,
        else => return false,
    }
}
