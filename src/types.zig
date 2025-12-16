const std = @import("std");
const numbers = @import("numbers.zig");

pub const Param = struct {
    name: []const u8,
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

    Exit: struct {
        immediate: bool,
        text: ?*ASTNode,
    },

    ReturnSig: struct {
        can_error: bool,
        optional: bool,
        return_type: *ASTNode,
    },

    Import: struct {
        is_relative: bool,
        is_absolute: bool,
        is_builtin: bool,
        path: []const u8,
    },

    Return: ?*ASTNode,
    Bool: bool,
    Nil,

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

    //====== Other ======//
    Function, // fn Id(Id T) RHS
    DirectRet, // ->
    ErrorRet, // !>
    Call, // f(x)
};

pub const AST = struct {
    nodes: []ASTNode,
    index: usize = 0,

    pub fn next(self: *AST) ?*ASTNode {
        if (self.index >= self.nodes.len) return null;
        const index = self.index;
        self.index += 1;
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
            .RArrow => "->",
            .RErrorArrow => "!>",
            .LArrow => "<-",
            .LErrorArrow => "<!",
            .ROptionalArrow => "?->",
            .ROptionalErrorArrow => "?!>",
            .LOptionalArrow => "?<-",
            .LOptionalErrorArrow => "?<!",
            .ColonColon => "::",
            .DashDash => "--",
            .PlusPlus => "++",
            .LessOrEqual => "<=",
            .GreaterOrEqual => ">=",
            .EqualEqual => "==",
            .BangEqual => "!=",
            .ColonEqual => ":=",
            .HashEqual => "#=",
            .String => "String",
            .Word => "Word",
            .Number => {
                if (self.number_kind) |kind| {
                    return switch (kind) {
                        .DecimalInt => "Decimal Integer",
                        .DecimalFloat => "Decimal Float",
                        .HexInt => "Hexadecimal Integer",
                        .HexFloat => "Hexadecimal Float",
                        .BinaryInt => "Binary Integer",
                        .BinaryFloat => "Binary Float",
                    };
                } else {
                    return "Number";
                }
            },
            else => "\u{FFFD}",
        };
    }
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
    Bang, // !
    At, // @
    Hash, // #
    Tilde, // ~
    Colon, // :
    ColonColon, // ::
    DashDash, // --
    PlusPlus, // ++

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

    //====== Arrows ======//
    RArrow, // ->
    RErrorArrow, // !>
    LArrow, // <-
    LErrorArrow, // <!
    ROptionalArrow, // ?->
    ROptionalErrorArrow, // ?!>
    LOptionalArrow, // ?<-
    LOptionalErrorArrow, // ?<!

    //====== Inequality ======//
    LessOrEqual, // <=
    GreaterOrEqual, // >=
    EqualEqual, // ==
    BangEqual, // !=

    //====== Assignment ======//
    ColonEqual, // :=
    HashEqual, // #=

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
        if (self.index >= self.tokens.len) return null;
        const index = self.index;
        self.index += 1;
        return &self.tokens[index];
    }

    pub fn peek(self: *TokenIterator, distance: usize) ?*Token {
        if (self.index + distance >= self.tokens.len) return null;
        return &self.tokens[self.index + distance];
    }
};
