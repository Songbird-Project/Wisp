const std = @import("std");
const lexer = @import("lexer.zig");
const ast = @import("ast.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const alloc = arena.allocator();

    var argv = try std.process.argsWithAllocator(alloc);
    defer argv.deinit();
    _ = argv.next();
    const filename = if (argv.next()) |a| std.mem.sliceTo(a, 0) else "main.wp";
    const src = try lexer.readFile(alloc, filename);

    var tokens = try lexer.lex(alloc, filename, src);
    if (tokens == .err) {
        const err = tokens.err;
        std.debug.print("{s}\n", .{err.message});
        std.process.exit(err.code);
    }

    const tree = try ast.parse(alloc, filename, src, &tokens.ok);
    if (tree == .err) {
        const err = tree.err;
        std.debug.print("{s}\n", .{err.message});
        std.process.exit(err.code);
    }
}
