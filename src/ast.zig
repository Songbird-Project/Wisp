const std = @import("std");
const types = @import("types.zig");
const errors = @import("error.zig");
const numbers = @import("numbers.zig");

pub fn parse(alloc: std.mem.Allocator, filename: []const u8, src: [][]u8, tokens: *types.TokenIterator) !errors.Result(types.AST) {
    var nodes: std.ArrayList(types.ASTNode) = .empty;

    while (tokens.peek(0)) |token| {
        var node: ?types.ParserReturn = null;

        switch (token.kind) {
            .Hash => {
                node = parseDirective(tokens);
            },
            .Fn => {
                // TODO: parseFn
            },
            .Return => {
                // TODO: parseReturn
            },
            .Exit => {
                node = parseExit(tokens);
            },
            .Id => {
                const id = tokens.peek(1) orelse break;
                switch (id.kind) {
                    .ColonColon => {
                        // TODO: parseType
                    },
                    .Period => {
                        // TODO: parseCall
                    },
                    .ColonEqual, .HashEqual, .Equals => {
                        // TODO: parseAssign
                    },
                    else => {},
                }
            },
            else => {},
        }

        if (node == null) {
            return .{
                .err = .{
                    .message = try errors.format(
                        alloc,
                        "unexpected token in top level of file",
                        filename,
                        src[token.line_num],
                        token.kindToChar(),
                        token.line_num,
                        token.line_col,
                        token.line_col_end,
                    ),
                    .code = 1,
                },
            };
        }

        if (node.? == .err) {
            const err = node.?.err;
            return .{
                .err = .{
                    .message = try errors.format(
                        alloc,
                        err.message,
                        filename,
                        src[err.token.line_num],
                        null,
                        err.token.line_num,
                        err.token.line_col,
                        err.token.line_col_end,
                    ),
                    .code = err.code,
                },
            };
        }

        if (tokens.expect(.Newline) == null) {
            const newline = tokens.tokens[tokens.index - 2];

            return .{
                .err = .{
                    .message = try errors.format(
                        alloc,
                        "expected newline after statement",
                        filename,
                        src[newline.line_num],
                        null,
                        newline.line_num,
                        newline.line_col + 1,
                        newline.line_col_end + 1,
                    ),
                    .code = 1,
                },
            };
        }

        try nodes.append(alloc, node.?.ok);
    }

    return .{
        .ok = .{
            .nodes = try nodes.toOwnedSlice(alloc),
        },
    };
}

fn parseDirective(tokens: *types.TokenIterator) types.ParserReturn {
    var node: types.ASTNode = undefined;

    const hash = tokens.next().?;

    const name: ?*types.Token = tokens.expect(.Id);
    if (name == null) {
        return .{
            .err = .{
                .token = hash.*,
                .message = "expected directive name after `#`",
                .code = 1,
            },
        };
    }

    if (tokens.expect(.LBracket) == null) {
        return .{
            .err = .{
                .token = name.?.*,
                .message = "expected arguments after directive name",
                .code = 1,
            },
        };
    }

    if (std.mem.eql(u8, name.?.value, "import")) {
        const import = parseImport(tokens);
        if (import == .err) return .{ .err = import.err };
        node = import.ok;
    } else {
        return .{
            .err = .{
                .token = name.?.*,
                .message = "unkown directive",
                .code = 1,
            },
        };
    }

    if (tokens.expect(.RBracket) == null) {
        return .{
            .err = .{
                .token = tokens.tokens[tokens.index - 1],
                .message = "expected closing bracket after arguments",
                .code = 1,
            },
        };
    }

    return .{ .ok = node };
}

fn parseImport(tokens: *types.TokenIterator) types.ParserReturn {
    var kind: types.ImportKind = .Builtin;
    const path = tokens.expect(.String);
    if (path == null) {
        return .{
            .err = .{
                .token = tokens.tokens[tokens.index - 1],
                .message = "expected library or file in import directive",
                .code = 1,
            },
        };
    } else {
        if (std.mem.startsWith(u8, path.?.value, "/")) {
            kind = .Absolute;
        } else if (std.mem.startsWith(u8, path.?.value, "./")) {
            kind = .Relative;
        }
    }

    return .{
        .ok = .{
            .Import = .{
                .kind = kind,
                .path = path.?.value,
            },
        },
    };
}

fn parseExit(tokens: *types.TokenIterator) types.ParserReturn {
    _ = tokens.next();

    var immediate_exit: bool = true;
    var exit_value: ?*types.ASTNode = null;

    const arrow = tokens.peek(1);
    if (arrow != null and arrow.?.kind != .Newline) {
        _ = tokens.next();

        switch (arrow.?.kind) {
            .LErrorArrow => immediate_exit = true,
            .LArrow => immediate_exit = false,
            else => return .{
                .err = .{
                    .token = arrow.?.*,
                    .message = "invalid arrow after exit keyword",
                    .code = 1,
                },
            },
        }

        const value = tokens.next();
        if (value == null or (value.?.kind != .Number and value.?.number_kind.? != .DecimalInt)) {
            return .{
                .err = .{
                    .token = arrow.?.*,
                    .message = "expected value for exit",
                    .code = 1,
                },
            };
        }

        var value_node: types.ASTNode = .{
            .Number = .{
                .kind = numbers.NumberKind.DecimalInt,
                .value = value.?.value,
            },
        };

        exit_value = &value_node;
    }

    return .{
        .ok = .{
            .Exit = .{
                .immediate = immediate_exit,
                .value = exit_value,
            },
        },
    };
}
