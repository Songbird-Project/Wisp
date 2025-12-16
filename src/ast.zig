const std = @import("std");
const types = @import("types.zig");
const errors = @import("error.zig");
const numbers = @import("numbers.zig");

pub fn parse(alloc: std.mem.Allocator, filename: []const u8, src: [][]u8, tokens: *types.TokenIterator) !errors.Result(types.AST) {
    var nodes: std.ArrayList(types.ASTNode) = .empty;

    while (tokens.next()) |token| {
        var node: ?types.ASTNode = null;

        switch (token.kind) {
            .Hash => {
                const directiveNode = parseDirective(tokens);
                if (directiveNode == .err) {
                    const err = directiveNode.err;
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

                node = directiveNode.ok;
            },
            .Fn => {
                // TODO: parseFn
            },
            .Return => {
                // TODO: parseReturn
            },
            .Exit => {
                // TODO: parseExit
            },
            .Id => {
                if (tokens.peek(1).?.kind == .ColonColon) {
                    // TODO: parseTypeDef
                } else if (isAssign(tokens.peek(1).?.kind)) {
                    // TODO: parseAssign
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

        try nodes.append(alloc, node.?);
    }

    return .{
        .ok = .{
            .nodes = try nodes.toOwnedSlice(alloc),
        },
    };
}

fn parseDirective(tokens: *types.TokenIterator) union(enum) {
    ok: types.ASTNode,
    err: struct {
        token: types.Token,
        message: []const u8,
        code: u8,
    },
} {
    var node: types.ASTNode = undefined;
    var err: usize = 1;
    if (tokens.peek(1) != null) {
        err = 2;
    }

    const name: ?*types.Token = tokens.expect(.Id);
    if (name == null) {
        return .{
            .err = .{
                .token = tokens.tokens[tokens.index - err],
                .message = "expected directive name after `#`",
                .code = 1,
            },
        };
    }

    var token: ?*types.Token = tokens.expect(.LBracket);
    if (token == null) {
        return .{
            .err = .{
                .token = tokens.tokens[tokens.index - 1],
                .message = "expected arguments after directive name",
                .code = 1,
            },
        };
    }

    if (std.mem.eql(u8, name.?.value, "import")) {
        const path = tokens.expect(.String);
        if (path == null) {
            return .{
                .err = .{
                    .token = tokens.tokens[tokens.index - 1],
                    .message = "expected library or file in import directive",
                    .code = 1,
                },
            };
        }

        node = .{
            .Import = .{
                .kind = .Builtin,
                .path = path.?.value,
            },
        };
    } else {
        return .{
            .err = .{
                .token = tokens.tokens[tokens.index - 1],
                .message = "unkown directive",
                .code = 1,
            },
        };
    }

    token = tokens.expect(.RBracket);
    if (token == null) {
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

fn isAssign(kind: types.TokKind) bool {
    return switch (kind) {
        .ColonEqual, .HashEqual, .Equals => true,
        else => false,
    };
}
