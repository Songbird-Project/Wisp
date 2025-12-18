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
                node = try parseDirective(alloc, tokens);
            },
            .Fn => {
                // TODO: parseFn
            },
            .Return => {
                // TODO: parseReturn
            },
            .Exit => {
                node = try parseExit(alloc, tokens);
            },
            else => {},
        }

        if (node == null) {
            node = try parseExpr(alloc, tokens, 0);
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

fn parseExpr(alloc: std.mem.Allocator, tokens: *types.TokenIterator, min_bp: u8) !types.ParserReturn {
    const lhs_tok = tokens.next().?;
    var lhs: types.ASTNode = .Nil;
    var rhs: types.ASTNode = .Nil;

    if (prefixBP(lhs_tok.kind)) |bp| {
        const expr = try parseExpr(alloc, tokens, bp);
        if (expr == .err) return .{ .err = expr.err };
        rhs = expr.ok;
        const kind: types.ASTKind = switch (lhs_tok.kind) {
            .Dash => .Negate,
            .Bang => .Not,
            .BNot => .BNot,
            .PlusPlus => .Increment,
            .DashDash => .Decrement,
            .ColonColon => .TypeOf,
            else => unreachable,
        };

        lhs = .{
            .PrefixOp = .{
                .kind = kind,
                .value = &rhs,
            },
        };
    } else if (isAtom(lhs_tok.kind)) {
        lhs = switch (lhs_tok.kind) {
            .String => .{ .String = lhs_tok.value },
            .Id => .{ .Identifier = lhs_tok.value },
            .Number => .{
                .Number = .{
                    .kind = lhs_tok.number_kind.?,
                    .value = lhs_tok.value,
                },
            },
            else => unreachable,
        };
    } else if (lhs_tok.kind == .LBracket) {
        const expr = try parseExpr(alloc, tokens, 0);
        if (expr == .err) return .{ .err = expr.err };
        lhs = expr.ok;
        if (tokens.expect(.RBracket) == null) {
            return .{
                .err = .{
                    .token = lhs_tok.*,
                    .message = "expected closing bracket",
                    .code = 1,
                },
            };
        }
    } else {
        return .{
            .err = .{
                .token = lhs_tok.*,
                .message = "unexpected token in top level of file",
                .code = 1,
            },
        };
    }

    while (tokens.peek(0)) |tok| {
        if (postfixBP(tok.kind)) |bp| {
            if (bp < min_bp) break;
            _ = tokens.next();

            if (tok.kind == .LBracket) {
                var args: std.ArrayList(*types.ASTNode) = .empty;
                while (tokens.peek(0) != null and tokens.peek(0).?.kind != .Newline and tokens.peek(0).?.kind != .RBracket) {
                    var expr = try parseExpr(alloc, tokens, 0);
                    if (expr == .err) return .{ .err = expr.err };
                    try args.append(alloc, &expr.ok);
                    if (tokens.peek(0).?.kind == .Comma) _ = tokens.next();
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

                lhs = .{
                    .Call = .{
                        .callee = &lhs,
                        .args = try args.toOwnedSlice(alloc),
                    },
                };
            } else {
                const kind: types.ASTKind = switch (tok.kind) {
                    .PlusPlus => .Increment,
                    .DashDash => .Decrement,
                    else => unreachable,
                };

                lhs = .{
                    .PostfixOp = .{
                        .kind = kind,
                        .value = &lhs,
                    },
                };
            }

            continue;
        }

        if (infixBP(tok.kind)) |bps| {
            if (bps.left < min_bp) break;

            _ = tokens.next();

            const expr = try parseExpr(alloc, tokens, bps.right);
            if (expr == .err) {
                return .{ .err = expr.err };
            }
            rhs = expr.ok;
            const kind: types.ASTKind = switch (tok.kind) {
                .Equals => .Reassign,
                .ColonEqual => .AssignVar,
                .HashEqual => .AssignConst,
                .And => .And,
                .Pipe => .Or,
                .LAngle => .Lesser,
                .RAngle => .Greater,
                .LessOrEqual => .LesserOrEqual,
                .GreaterOrEqual => .GreaterOrEqual,
                .EqualEqual => .Equal,
                .BangEqual => .NotEqual,
                .Plus => .Add,
                .Dash => .Sub,
                .Star => .Mul,
                .FSlash => .Div,
                .Percent => .Mod,
                .Caret => .Pow,
                .BAnd => .BAnd,
                .BXor => .BXor,
                .BOr => .BOr,
                .ColonColon => .Type,
                else => unreachable,
            };

            lhs = .{
                .BinaryOp = .{
                    .kind = kind,
                    .lhs = &lhs,
                    .rhs = &rhs,
                },
            };

            continue;
        }

        break;
    }

    return .{ .ok = lhs };
}

fn parseDirective(alloc: std.mem.Allocator, tokens: *types.TokenIterator) !types.ParserReturn {
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
        const import = try parseImport(alloc, tokens);
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

fn parseImport(alloc: std.mem.Allocator, tokens: *types.TokenIterator) !types.ParserReturn {
    var path = try parseExpr(alloc, tokens, 0);
    if (path == .err) {
        return .{
            .err = .{
                .token = path.err.token,
                .message = "expected library or file in import directive",
                .code = 1,
            },
        };
    }

    return .{
        .ok = .{ .Import = &path.ok },
    };
}

fn parseExit(alloc: std.mem.Allocator, tokens: *types.TokenIterator) !types.ParserReturn {
    _ = tokens.next();

    var immediate_exit: bool = true;
    var exit_value: ?*types.ASTNode = null;

    const arrow = tokens.peek(0);
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
        if (value == null) {
            return .{
                .err = .{
                    .token = if (value != null) value.?.* else arrow.?.*,
                    .message = "expected value after arrow",
                    .code = 1,
                },
            };
        }

        var value_node = try parseExpr(alloc, tokens, 0);
        if (value_node == .err) return .{ .err = value_node.err };

        exit_value = &value_node.ok;
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

fn infixBP(kind: types.TokKind) ?struct { left: u8, right: u8 } {
    return switch (kind) {
        .Equals, .ColonEqual, .HashEqual => .{ .left = 1, .right = 2 },
        .And => .{ .left = 3, .right = 4 },
        .Pipe => .{ .left = 2, .right = 3 },
        .LAngle, .RAngle, .LessOrEqual, .GreaterOrEqual, .EqualEqual, .BangEqual => .{ .left = 5, .right = 6 },
        .Plus, .Dash => .{ .left = 7, .right = 8 },
        .Star, .FSlash, .Percent => .{ .left = 9, .right = 10 },
        .Caret => .{ .left = 11, .right = 12 },
        .BAnd => .{ .left = 13, .right = 14 },
        .BXor => .{ .left = 12, .right = 13 },
        .BOr => .{ .left = 11, .right = 12 },
        .ColonColon => .{ .left = 1, .right = 2 },

        else => null,
    };
}

fn prefixBP(kind: types.TokKind) ?u8 {
    return switch (kind) {
        .ColonColon => 15,
        .Dash, .Bang, .BNot => 16,
        .PlusPlus, .DashDash => 17,
        else => null,
    };
}

fn postfixBP(kind: types.TokKind) ?u8 {
    return switch (kind) {
        .PlusPlus, .DashDash => 18,
        .LBracket => 19,
        else => null,
    };
}

fn isAtom(kind: types.TokKind) bool {
    return switch (kind) {
        .String, .Number, .Id => true,
        else => false,
    };
}
