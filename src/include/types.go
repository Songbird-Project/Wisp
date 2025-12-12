package include

import "bufio"

type Parser struct {
	LineNum int
	LineCol int
	Context ASTKind

	Scanner bufio.Scanner
}

type Error struct {
	Info     string
	ExitCode int
}

type ASTNode struct {
	Kind ASTKind

	LHS      *ASTNode
	RHS      *ASTNode
	Alt      *ASTNode
	Children []*ASTNode
	Params   [][]*ASTNode
	Value    string
}

type ASTKind int

const (
	//=====================//
	//      AST Kinds      //
	//=====================//

	//====== Binary operators ======//
	// Maths
	AST_Add ASTKind = iota // LHS + RHS
	AST_Sub                // LHS - RHS
	AST_Div                // LHS / RHS
	AST_Mul                // LHS * RHS
	AST_Pow                // LHS ^ RHS
	AST_Mod                // LHS % RHS

	// Logic
	AST_And // LHS & RHS
	AST_Or  // LHS | RHS

	// Bitwise
	AST_BAnd   // LHS .& RHS
	AST_BOr    // LHS .| RHS
	AST_BXor   // LHS .^ RHS
	AST_BLeft  // LHS .< RHS
	AST_BRight // LHS .> RHS

	// Equality
	AST_Equal          // LHS == RHS
	AST_NotEqual       // LHS != RHS
	AST_Greater        // LHS > RHS
	AST_Lesser         // LHS < RHS
	AST_GreaterOrEqual // LHS >= RHS
	AST_LesserOrEqual  //LHS <= RHS

	// Assignment
	AST_Variable // LHS := RHS
	AST_Constant // LHS #= RHS
	AST_TypeCast // LHS :: RHS
	AST_Assign   // LHS = RHS

	//====== Unary Operators ======//
	AST_Not    // !LHS
	AST_Inc    // LHS++
	AST_Dec    // LHS--
	AST_TypeOf // ::LHS
	AST_BNot   // .!LHS

	//====== Values ======//
	AST_Int    // 32
	AST_Float  // 32.45
	AST_Binary // 0b101
	AST_Hex    // 0xF3
	AST_String // "..."
	AST_List   // [...]Id{...}
	AST_Id     // name
	AST_ListId // [...]Id

	//====== Conditionals ======//
	AST_If    // if LHS RHS ALT
	AST_Else  // else LHS
	AST_While // while LHS RHS
	AST_For   // for LHS RHS

	//====== Keywords ======//
	AST_Return   // return LHS
	AST_Exit     // exit
	AST_ExitCode // exit <- LHS
	AST_ExitNow  // exit <! LHS
	AST_True     // true
	AST_False    // false
	AST_Nil      // nil

	//====== Returns ======//
	AST_ReturnOnly   // -> LHS RHS
	AST_ReturnNil    // ~> LHS RHS
	AST_ReturnErr    // !> LHS RHS
	AST_ReturnErrNil // ?> LHS RHS

	//====== Other ======//
	AST_Root     // FILE
	AST_Function // fn Id(Id T) RHS
	AST_Block    // {...}
	AST_Group    // (...)
	AST_Call     // f(x)
)

var AST_Num = []ASTKind{AST_Int, AST_Float, AST_Hex, AST_Binary}
var AST_Math = []ASTKind{AST_Add, AST_Sub, AST_Mul, AST_Div, AST_Pow, AST_Mod}
var AST_Bitwise = []ASTKind{AST_BAnd, AST_BOr, AST_BXor, AST_BNot}
var AST_Bool = []ASTKind{AST_True, AST_False}

var astName = map[ASTKind]string{
	//====== Binary operators ======//
	// Maths
	AST_Add: "Add",
	AST_Sub: "Subtract",
	AST_Div: "Divide",
	AST_Mul: "Multiply",
	AST_Pow: "Exponential",
	AST_Mod: "Modulo",

	// Logic
	AST_And: "And",
	AST_Or:  "Or",

	// Bitwise
	AST_BAnd:   "Bitwise And",
	AST_BOr:    "Bitwise Or",
	AST_BXor:   "Bitwise Xor",
	AST_BLeft:  "Left Shift",
	AST_BRight: "Right Shift",

	// Equality
	AST_Equal:          "Equal",
	AST_NotEqual:       "Not Equal",
	AST_Greater:        "Greater",
	AST_Lesser:         "Lesser",
	AST_GreaterOrEqual: "Greater or Equal",
	AST_LesserOrEqual:  "Lesser or Equal",

	// Assignment
	AST_Variable: "Variable Declaration",
	AST_Constant: "Constant Declaration",
	AST_TypeCast: "Type Cast",
	AST_Assign:   "Variable Assignment",

	//====== Unary Operators ======//
	AST_Not:    "Not",
	AST_Inc:    "Increment",
	AST_Dec:    "Decrement",
	AST_TypeOf: "Type Of",
	AST_BNot:   "Bitwise Not",

	//====== Values ======//
	AST_Int:    "Integer",
	AST_Float:  "Float",
	AST_Binary: "Binary",
	AST_Hex:    "Hexadecimal",
	AST_String: "String",
	AST_List:   "List",
	AST_Id:     "Identifier",
	AST_ListId: "List-type Identifier",

	//====== Conditionals ======//
	AST_If:    "If Statement",
	AST_Else:  "Else Statement",
	AST_While: "While Statement",
	AST_For:   "For Statement",

	//====== Keywords ======//
	AST_Return:   "Return",
	AST_Exit:     "Exit",
	AST_ExitCode: "Exit Code",
	AST_ExitNow:  "Exit Now",
	AST_True:     "True",
	AST_False:    "False",
	AST_Nil:      "Nil",

	//====== Returns ======//
	AST_ReturnOnly:   "Return Only",
	AST_ReturnNil:    "Return Nil",
	AST_ReturnErr:    "Return Error",
	AST_ReturnErrNil: "Return Nil or Error",

	//====== Other ======//
	AST_Root:     "Root",
	AST_Function: "Function Declaration",
	AST_Block:    "Block",
	AST_Group:    "Group",
	AST_Call:     "Function Call",
}

func (astType ASTKind) String() string {
	return astName[astType]
}

func (astType ASTKind) Class() string {
	switch astType {
	case AST_Add, AST_Sub, AST_Div, AST_Mul, AST_Pow, AST_Mod, AST_Inc, AST_Dec:
		return "Math"
	case AST_And, AST_Or, AST_Not:
		return "Logic"
	case AST_BAnd, AST_BOr, AST_BXor, AST_BLeft, AST_BRight, AST_BNot:
		return "Bitwise"
	case AST_Equal, AST_NotEqual, AST_Greater, AST_Lesser, AST_GreaterOrEqual, AST_LesserOrEqual:
		return "Equality"
	case AST_Variable, AST_Constant, AST_TypeCast, AST_Function:
		return "Assignment"
	case AST_If, AST_Else, AST_For, AST_While:
		return "Conditional"
	case AST_Return, AST_Exit, AST_ExitCode, AST_ExitNow, AST_Nil, AST_True, AST_False:
		return "Keyword"
	case AST_ReturnOnly, AST_ReturnNil, AST_ReturnErr, AST_ReturnErrNil:
		return "Return"
	default:
		return "Other"
	}
}
