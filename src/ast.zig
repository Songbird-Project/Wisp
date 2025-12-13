const std = @import("std");
const types = @import("./types.zig");
const errors = @import("./error.zig");

pub fn parse(alloc: std.mem.Allocator, filename: []const u8, src: [][]u8, tokens: *types.TokenIterator) !errors.Result(types.AST) {
    var nodes: std.ArrayList(types.AstNode) = .empty;

    while (tokens.next()) |token| {
        var node: types.AstNode = .{};

        if (token.kind == .Word) {
            node.kind = .Id;
            node.value = token.value;
        } else {
            return .{
                .err = .{
                    .message = try errors.format(
                        alloc,
                        "unexpected token",
                        filename,
                        src[token.line_num],
                        types.TokKind.kindToChar(token.kind),
                        token.line_num + 1,
                        token.line_col,
                        token.line_col_end,
                    ),
                    .code = 1,
                },
            };
        }
    }

    return .{
        .ok = .{
            .nodes = try nodes.toOwnedSlice(alloc),
        },
    };
}
