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
