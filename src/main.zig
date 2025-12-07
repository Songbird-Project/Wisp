const std = @import("std");
const ast = @import("./ast.zig");

pub fn main() !void {
    var gpa = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    _ = try ast.Parse(alloc);
}
