const std = @import("std");

pub const astNode = struct {
    kind: astType = astType.Root,

    lhs: ?*astNode = null,
    rhs: ?*astNode = null,
    alt: ?*astNode = null,
    children: ?*std.ArrayList(astNode) = null,
    params: ?*std.ArrayList([]const u8) = null,
    name: ?*[]u8 = null,
};

pub const astType = enum {
    //====== Binary operators ======//
    // Maths
    Add, // LHS + RHS
    Sub, // LHS - RHS
    Div, // LHS / RHS
    Mul, // LHS * RHS
    Pow, // LHS ^ RHS
    Mod, // LHS % RHS

    // Logic
    And, // LHS & RHS
    Or, // LHS | RHS

    // Bitwise
    BAnd, // LHS .& RHS
    BOr, // LHS .| RHS
    BXor, // LHS .^ RHS
    BLeft, // LHS .< RHS
    BRight, // LHS .> RHS

    // Equality
    Equal, // LHS == RHS
    NotEqual, // LHS != RHS
    Greater, // LHS > RHS
    Lesser, // LHS < RHS
    GreaterOrEqual, // LHS >= RHS
    LesserOrEqual, //LHS <= RHS

    // Assignment
    Variable, // LHS := RHS
    Constant, // LHS #= RHS
    TypeCast, // LHS :: RHS

    //====== Unary Operators ======//
    Not, // !LHS
    Increment, // ++LHS
    Decrement, // --LHS
    TypeOf, // ::LHS
    BNot, // .!LHS

    //====== Values ======//
    Int, // 32
    Float, // 32.45
    Binary, // 0b101
    Hex, // 0xF3
    String, // "..."
    Id, // name

    //====== Keywords ======//
    Return, // return LHS
    ExitCode, // exit <- LHS
    If, // if LHS RHS ALT
    Else, // else LHS
    While, // while LHS RHS
    For, // for LHS RHS
    True, // true
    False, // false

    //====== Other ======//
    Root, // FILE
    Function, // fn Id(Id T) RHS
    ReturnSig, // [-~!?]> LHS RHS
    Block, // {...}
    Call, // f(x)
};

pub const Token = struct {
    kind: TokKind = TokKind.EOF,
    value: []const u8 = "",
};

pub const TokKind = enum {
    //====== Symbols ======//
    Plus, // +
    Dash, // -
    FSlash, // /
    Star, // *
    Percent, // %
    Caret, // ^
    Pipe, // |
    And, // &
    Equals, // =
    Dollar, // $
    Underscore, // _
    BSlash, // \
    Comma, // ,
    Period, // .
    Question, // ?
    Exclamation, // !
    At, // @
    Hash, // #
    Tilde, // ~
    Colon, // :

    Backtick, // `
    SingleQuote, // '
    DoubleQuote, // "

    LBracket, // (
    RBracket, // )
    LSquare, // [
    RSquare, // ]
    LBrace, // {
    RBrace, // }
    LAngle, // <
    RAngle, // >

    //====== Other ======//
    EOF, // End of file
    Number, // Consecutive `0-9`
    Word, // Consecutive `a-zA-Z`

    pub fn charToKind(char: u8) ?TokKind {
        return switch (char) {
            '+' => .Plus,
            '-' => .Dash,
            '/' => .FSlash,
            '*' => .Star,
            '%' => .Percent,
            '^' => .Caret,
            '|' => .Pipe,
            '&' => .And,
            '=' => .Equals,
            '$' => .Dollar,
            '_' => .Underscore,
            '\\' => .BSlash,
            ',' => .Comma,
            '.' => .Period,
            '?' => .Question,
            '!' => .Exclamation,
            '@' => .At,
            '#' => .Hash,
            '~' => .Tilde,
            ':' => .Colon,
            '`' => .Backtick,
            '\'' => .SingleQuote,
            '"' => .DoubleQuote,
            ')' => .RBracket,
            '(' => .LBracket,
            '[' => .LSquare,
            ']' => .RSquare,
            '{' => .LBrace,
            '}' => .RBrace,
            '<' => .LAngle,
            '>' => .RAngle,
            else => null,
        };
    }
};

pub const TokenIterator = struct {
    tokens: []Token,
    _index: u8 = 0,

    pub fn next(self: *TokenIterator) ?Token {
        const index = self._index;
        self._index += 1;
        return self.tokens[index];
    }
};

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
