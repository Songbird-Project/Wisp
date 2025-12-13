const std = @import("std");
const types = @import("./types.zig");
const errors = @import("./error.zig");

pub fn parse(alloc: std.mem.Allocator, filename: []const u8, tokens: *types.TokenIterator) !errors.Result(types.AST) {
    var nodes: std.ArrayList(types.AstNode) = .empty;

    while (tokens.next()) |token| {
        var node: types.AstNode = .{};

        if (token.kind == .Word) {
            node.kind = .Id;
            node.value = token.value;
        } else {
            return .{
                .err = .{
                    .message = try std.fmt.allocPrint(
                        alloc,
                        "unexpected token: {s}:{d}:{d} {c}",
                        .{
                            filename,
                            token.line_num,
                            token.line_col,
                            types.TokKind.kindToChar(token.kind),
                        },
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
