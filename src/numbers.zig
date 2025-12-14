const std = @import("std");

pub const NumberKind = enum {
    DecimalInt, // `0-9`
    DecimalFloat, // `0-9.`
    HexInt, // `0x0-F`
    HexFloat, // `0x0-F.`
    BinaryInt, // `0b0-1`
    BinaryFloat, // `0b0-1.`
};

pub const CharKind = struct {
    decimal_digit: bool,
    hex_digit: bool,
    binary_digit: bool,
    decimal_point: bool,
    decimal_exp: bool,
    binary_exp: bool,
    sign: bool,
    underscore: bool,
};

pub const char_kind: [256]CharKind = kinds: {
    var table: [256]CharKind = undefined;

    for (&table) |*class| {
        class.* = .{
            .decimal_digit = false,
            .hex_digit = false,
            .binary_digit = false,
            .decimal_point = false,
            .decimal_exp = false,
            .binary_exp = false,
            .sign = false,
            .underscore = false,
        };
    }

    //====== Digits ======//
    for ('0'..'9' + 1) |char| {
        table[char].decimal_digit = true;
        table[char].hex_digit = true;
        table[char].binary_digit = char == '0' or char == '1';
    }

    //====== Hex ======//
    for ('a'..'f' + 1) |char| table[char].hex_digit = true;
    for ('A'..'F' + 1) |char| table[char].hex_digit = true;

    //====== Decimal Point ======//
    table['.'].decimal_point = true;

    //====== Exponents ======//
    table['e'].decimal_exp = true;
    table['E'].decimal_exp = true;
    table['p'].binary_exp = true;
    table['P'].binary_exp = true;

    //====== Signs ======//
    table['+'].sign = true;
    table['-'].sign = true;

    //====== Other ======//
    table['_'].underscore = true;

    break :kinds table;
};

pub fn validChar(kind: NumberKind, char: u8) bool {
    const class = char_kind[char];

    return switch (kind) {
        .DecimalInt => class.decimal_digit or class.underscore,
        .DecimalFloat => class.decimal_digit or class.decimal_point or class.sign or class.underscore,
        .HexInt => class.hex_digit or class.underscore,
        .HexFloat => class.hex_digit or class.decimal_point or class.sign or class.underscore,
        .BinaryInt => class.binary_digit or class.underscore,
        .BinaryFloat => class.binary_digit or class.decimal_point or class.sign or class.underscore,
    };
}

pub fn validateUnderscores(line: []const u8, start: usize, end: usize) []const u8 {
    var prev: u8 = 0;
    for (start..end) |i| {
        const c = line[i];
        if (c == '_') {
            if (i == start) return "numbers cannot begin with `_`";
            if (i + 1 >= end) return "numbers cannot end with `_`";
            if (!std.ascii.isDigit(prev) or !std.ascii.isDigit(line[i + 1])) return "decimal point cannot follow or be followed by `_`";
        }
        prev = c;
    }

    return "";
}
