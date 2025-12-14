const std = @import("std");
const numbers = @import("numbers.zig");

pub const AstNode = struct {
    kind: AstType = .Root,

    lhs: ?*AstNode = null,
    rhs: ?*AstNode = null,
    alt: ?*AstNode = null,
    children: ?AST = null,
    params: ?[][]const u8 = null,
    value: []const u8 = "",
};

pub const AstType = enum {
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

pub const AST = struct {
    nodes: []AstNode,
    _index: u8 = 0,

    pub fn next(self: *AST) AstNode {
        const index = self._index;
        self._index += 1;
        return self.nodes[index];
    }
};

pub const Token = struct {
    kind: TokKind = .EOF,
    value: []const u8 = "",
    line_num: usize = 0,
    line_col: usize = 0,
    line_col_end: usize = 0,
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

    //====== Bitwise ======//
    BAnd, // .&
    BOr, // .|
    BXor, // .^
    BLeft, // .<
    BRight, // .>
    BNot, // .!

    //====== Numbers ======//
    DecimalInt, // `0-9`
    DecimalFloat, // `0-9.`
    HexInt, // `0x0-F`
    HexFloat, // `0x0-F.`
    BinaryInt, // `0b0-1`
    BinaryFloat, // `0b0-1.`

    //====== Other ======//
    EOF, // End of file
    Word, // `a-zA-Z`
    String, // "..."

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
            '\"' => .DoubleQuote,
            '(' => .LBracket,
            ')' => .RBracket,
            '[' => .LSquare,
            ']' => .RSquare,
            '{' => .LBrace,
            '}' => .RBrace,
            '<' => .LAngle,
            '>' => .RAngle,
            else => null,
        };
    }

    pub fn kindToChar(char: TokKind) []const u8 {
        return switch (char) {
            .Plus => "+",
            .Dash => "-",
            .FSlash => "/",
            .Star => "*",
            .Percent => "%",
            .Caret => "^",
            .Pipe => "|",
            .And => "&",
            .Equals => "=",
            .Dollar => "$",
            .Underscore => "_",
            .BSlash => "\\",
            .Comma => ",",
            .Period => ".",
            .Question => "?",
            .Exclamation => "!",
            .At => "@",
            .Hash => "#",
            .Tilde => "~",
            .Colon => ":",
            .Backtick => "`",
            .SingleQuote => "'",
            .DoubleQuote => "\"",
            .LBracket => "(",
            .RBracket => ")",
            .LSquare => "[",
            .RSquare => "]",
            .LBrace => "{",
            .RBrace => "}",
            .LAngle => "<",
            .RAngle => ">",
            .BAnd => ".&",
            .BOr => ".|",
            .BXor => ".^",
            .BLeft => ".<",
            .BRight => ".>",
            .BNot => ".!",
            .String => "String",
            .Word => "Word",
            .DecimalInt => "Decimal Integer",
            .DecimalFloat => "Decimal Float",
            .HexInt => "Hexadecimal Integer",
            .HexFloat => "Hexadecimal Float",
            .BinaryInt => "Binary Integer",
            .BinaryFloat => "Binary Float",
            else => "\u{FFFD}",
        };
    }
};

pub const TokenIterator = struct {
    tokens: []Token,
    index: u8 = 0,

    pub fn next(self: *TokenIterator) ?Token {
        const index = self.index;
        self.index += 1;
        return self.tokens[index];
    }
};
