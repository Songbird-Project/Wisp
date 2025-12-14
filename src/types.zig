const std = @import("std");
const numbers = @import("numbers.zig");

pub const Param = struct {
    name: *ASTNode,
    type: *ASTNode,
};

pub const ASTNode = union(enum) {
    Conditional: struct {
        kind: ASTKind,
        condition: *ASTNode,
        result: *ASTNode,
        alt: ?*ASTNode,
    },

    BinaryOp: struct {
        kind: ASTKind,
        lhs: *ASTNode,
        rhs: *ASTNode,
    },

    PrefixOp: struct {
        kind: ASTKind,
        lhs: *ASTNode,
    },

    PostfixOp: struct {
        kind: ASTKind,
        lhs: *ASTNode,
    },

    Function: struct {
        name: []const u8,
        params: []Param,
        sig: ASTKind,
        body: *ASTNode,
    },

    Call: struct {
        callee: *ASTNode,
        args: []*ASTNode,
    },

    Number: struct {
        kind: numbers.NumberKind,
        text: []const u8,
    },

    OptionalReturn: struct {
        base: ASTKind,
    },

    Optional: *ASTNode,
    Block: []*ASTNode,
    Identifier: []const u8,
    String: []const u8,

    Keyword: ASTKind,
};

pub const ASTKind = enum {
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
    Reassign, // LHS = RHS
    AssignVar, // LHS := RHS
    AssignConst, // LHS #= RHS
    TypeCast, // LHS :: RHS

    //====== Prefix Operators ======//
    Not, // !LHS
    Negate, // -LHS
    TypeOf, // ::LHS
    BNot, // .!LHS

    //====== Postfix Operators ======//
    Increment, // LHS++
    Decrement, // LHS--

    //====== Conditionals ======//
    If, // if CONDITION RESULT ALT
    While, // while CONDITION RESULT
    For, // for CONDITION RESULT

    //====== Keywords ======//
    Return, // return LHS
    ExitCode, // exit <- LHS
    Nil, // nil
    True, // true
    False, // false

    //====== Other ======//
    Function, // fn Id(Id T) RHS
    // ReturnSig, // [-~!?]> LHS RHS
    DirectRet, // ->
    ErrorRet, // !>
    // Block, // {...}
    Call, // f(x)
};

pub const AST = struct {
    nodes: []*ASTNode,
    _index: usize = 0,

    pub fn next(self: *AST) ?*ASTNode {
        const index = self._index;
        self._index += 1;
        return &self.nodes[index];
    }
};

pub const Token = struct {
    kind: TokKind = .EOF,
    number_kind: ?numbers.NumberKind = null,
    value: []const u8 = "",
    line_num: usize = 0,
    line_col: usize = 0,
    line_col_end: usize = 0,

    pub fn kindToChar(self: Token) []const u8 {
        return switch (self.kind) {
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
            .Bang => "!",
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
            .Number => {
                return switch (self.number_kind.?) {
                    .DecimalInt => "Decimal Integer",
                    .DecimalFloat => "Decimal Float",
                    .HexInt => "Hexadecimal Integer",
                    .HexFloat => "Hexadecimal Float",
                    .BinaryInt => "Binary Integer",
                    .BinaryFloat => "Binary Float",
                };
            },
            else => "\u{FFFD}",
        };
    }
};

pub const TokKind = union(enum) {
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
    Bang, // !
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

    //====== Other ======//
    EOF, // End of file
    Word, // `a-zA-Z`
    Number, // numbers.NumberKind
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
            '!' => .Bang,
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
};

pub const TokenIterator = struct {
    tokens: []Token,
    index: usize = 0,

    pub fn next(self: *TokenIterator) ?*Token {
        const index = self.index;
        self.index += 1;
        return &self.tokens[index];
    }
};
