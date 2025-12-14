const std = @import("std");

pub const Error = struct {
    message: []const u8,
    code: u8,
};

pub fn Result(comptime T: type) type {
    return union(enum) {
        ok: T,
        err: Error,
    };
}

pub fn format(
    alloc: std.mem.Allocator,
    text: []const u8,
    filename: []const u8,
    context: []const u8,
    symbol: ?[]const u8,
    line: usize,
    col_start: usize,
    col_end: usize,
) ![]const u8 {
    var columns: []u8 = undefined;
    if (col_start == col_end) {
        columns = try std.fmt.allocPrint(alloc, "{d}", .{col_start + 1});
    } else {
        columns = try std.fmt.allocPrint(alloc, "{d}-{d}", .{
            col_start + 1,
            col_end + 1,
        });
    }

    var symb: []u8 = undefined;
    if (symbol != null) {
        symb = try std.fmt.allocPrint(alloc, "`{s}`", .{symbol.?});
    } else {
        symb = "";
    }

    const message_line: []u8 = try std.fmt.allocPrint(
        alloc,
        "{s}: {s}:{d}:{s} {s}",
        .{
            text,
            filename,
            line + 1,
            columns,
            symb,
        },
    );

    const position_line: []u8 = try std.fmt.allocPrint(
        alloc,
        "{s}^{s}",
        .{
            try repeat(alloc, ' ', col_start),
            if (col_start != col_end) try repeat(alloc, '~', col_end - col_start) else "",
        },
    );

    return try std.fmt.allocPrint(alloc, "{s}\n{s}\n{s}", .{ message_line, context, position_line });
}

fn repeat(alloc: std.mem.Allocator, char: u8, times: usize) ![]u8 {
    const buf = try alloc.alloc(u8, times);
    @memset(buf, char);
    return buf;
}
