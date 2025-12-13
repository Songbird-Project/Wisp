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
            var columns: []const u8 = undefined;
            if (token.line_col == token.line_col_end) {
                columns = try std.fmt.allocPrint(alloc, "{d}", .{token.line_col + 1});
            } else {
                columns = try std.fmt.allocPrint(alloc, "{d}-{d}", .{
                    token.line_col + 1,
                    token.line_col_end + 1,
                });
            }

            return .{
                .err = .{
                    .message = try std.fmt.allocPrint(
                        alloc,
                        "unexpected token: {s}:{d}:{s} `{s}`\n{s}",
                        .{
                            filename,
                            token.line_num + 1,
                            columns,
                            types.TokKind.kindToString(token.kind),
                            src[token.line_num],
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
