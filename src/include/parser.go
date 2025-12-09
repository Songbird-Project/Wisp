package include

import (
	"bufio"
	"fmt"
	"os"
	"slices"
	"strings"
	"unicode"
)

func GenerateAST() (ASTNode, *Error) {
	srcPath := "main.wp"
	if len(os.Args) > 1 {
		srcPath = os.Args[1]
	}

	file, err := os.Open(srcPath)
	if err != nil {
		return ASTNode{}, &Error{err.Error(), 10}
	}
	defer file.Close()

	rootNode := ASTNode{
		Kind: AST_Root,
	}

	tree := []*ASTNode{}

	lineNum := 1
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())

		if len(line) == 0 || len(line) >= 2 && line[0:2] == "//" {
			lineNum++
			continue
		}

		nodes, err, _ := parseLine(line, -1)
		if err != nil {
			return ASTNode{}, err
		}

		tree = append(tree, nodes...)
		lineNum++
	}

	rootNode.Children = tree

	return rootNode, nil
}

func parseLine(line string, exprs int) ([]*ASTNode, *Error, int) {
	line = strings.TrimSpace(line)

	nodes := []*ASTNode{}
	var char int

	for char = 0; char < len(line); char++ {
		if exprs == 0 {
			break
		}

		node := &ASTNode{}

		// Skip all whitespace
		if unicode.IsSpace(rune(line[char])) {
			exprs++

			for unicode.IsSpace(rune(line[char])) && char < len(line) {
				char++
			}
		}

		// Parse identifiers
		if unicode.IsLetter(rune(line[char])) {
			node.Kind = AST_Id

			for symbol := char; symbol < len(line) && unicode.IsLetter(rune(line[symbol])); symbol++ {
				node.Value += string(line[symbol])
				char++
			}

			char--
			// Parse numbers
		} else if unicode.IsNumber(rune(line[char])) {
			node.Kind = AST_Int

			for symbol := char; symbol < len(line) && !unicode.IsSpace(rune(line[symbol])); symbol++ {
				node.Value += string(line[symbol])

				if unicode.IsLetter(rune(line[symbol])) {
					switch node.Kind {
					case AST_Int:
						node.Kind = AST_Id

						if symbol > 0 && line[symbol-1] == '0' {
							switch line[symbol] {
							case 'x':
								node.Kind = AST_Hex
							case 'b':
								node.Kind = AST_Binary
							}
						}
					case AST_Binary:
						err := fmt.Sprintf("Invalid symbol found in binary, expected `0` or `1`: `%s`", string(line[symbol]))
						return nil, &Error{err, 20}, char
					case AST_Hex:
						if !strings.Contains("ABCDEFabcdef", string(line[symbol])) {
							err := fmt.Sprintf("Invalid symbol found in hexadecimal, expected `0-9`, `a-f` or `A-F`: `%s`", string(line[symbol]))
							return nil, &Error{err, 20}, char
						}
					case AST_Float:
						err := fmt.Sprintf("Invalid symbol in float, expected `0-9`: `%s`", string(line[symbol]))
						return nil, &Error{err, 21}, char
					}
				} else if line[symbol] == '.' {
					if char < len(line) && unicode.IsSymbol(rune(line[char+1])) {
						node.Value = node.Value[:len(node.Value)-1]
						char--
						break
					} else if node.Kind == AST_Float {
						err := fmt.Sprintf("Invalid symbol in float, expected `0-9`: `%s`", string(line[symbol]))
						return nil, &Error{err, 21}, char
					} else {
						node.Kind = AST_Float
					}
				} else if unicode.IsSymbol(rune(line[symbol])) || strings.Contains("+-*/^%", string(line[symbol])) {
					node.Value = node.Value[:len(node.Value)-1]
					char--
					break
				}

				if !unicode.IsSymbol(rune(line[symbol])) {
					char++
				}
			}
			// Parse strings
		} else if strings.Contains("'\"`", string(line[char])) {
			node = &ASTNode{
				Kind: AST_String,
			}

			// Move over the first quote
			char++

			for symbol := char; symbol < len(line) && !strings.Contains("'\"`", string(line[char])); symbol++ {
				node.Value += string(line[symbol])
				char++
			}

			if !strings.Contains("'\"`", string(line[char])) {
				err := "Missing string terminator"
				return nil, &Error{err, 23}, char
			}
		} else if strings.Contains("+-*/%^.", string(line[char])) {
			opNode, newChar, newNodes, err := parseOp(line, char, nodes)
			if err != nil {
				return nil, err, char
			}

			node = opNode
			char = newChar
			nodes = newNodes
		} else if strings.Contains("=<>", string(line[char])) {
			eqNode, newChar, newNodes, err := parseEq(line, char, nodes)
			if err != nil {
				return nil, err, char
			}

			node = eqNode
			char = newChar
			nodes = newNodes
		} else if line[char] == '!' {
			notNode, newChar, newNodes, err := parseNot(line, char, nodes)
			if err != nil {
				return nil, err, char
			}

			node = notNode
			char = newChar
			nodes = newNodes
		} else if line[char] == ':' {
			opNode, newChar, newNodes, err := parseTypeOp(line, char, nodes)
			if err != nil {
				return nil, err, char
			}

			node = opNode
			char = newChar
			nodes = newNodes
		} else {
			err := fmt.Sprintf("Invalid symbol: `%s`", string(line[char]))
			return nil, &Error{err, 22}, char
		}

		exprs--
		nodes = append(nodes, node)
	}

	// for _, node := range nodes {
	// fmt.Printf("Value: %s, Kind: %s\n", node.Value, node.Kind)
	// }

	return nodes, nil, char
}

func parseOp(line string, char int, nodes []*ASTNode) (*ASTNode, int, []*ASTNode, *Error) {
	node := &ASTNode{}

	if len(nodes) == 0 || nodes == nil ||
		!slices.Contains(append(append(AST_Num, AST_String, AST_Id), append(AST_Math, AST_Bitwise...)...), nodes[max(0, len(nodes)-1)].Kind) {
		err := "Expected number or string as LHS of operator"
		return nil, char, nodes, &Error{err, 24}
	}

	node.LHS = nodes[max(0, len(nodes)-1)]

	switch line[char] {
	//====== Math ======//
	case '+':
		node.Kind = AST_Add
		char++

		if char < len(line) && line[char] == '+' {
			fmt.Println("Increment")
			node.Kind = AST_Inc
			if nodes[max(0, len(nodes)-1)].Kind == AST_String {
				err := "Expected number as LHS of increment"
				return nil, char, nodes, &Error{err, 24}
			}

			char++
		}
	case '-':
		node.Kind = AST_Sub
		char++

		if char < len(line) && line[char] == '-' {
			node.Kind = AST_Dec

			if nodes[max(0, len(nodes)-1)].Kind == AST_String {
				err := "Expected number as LHS of decrement"
				return nil, char, nodes, &Error{err, 24}
			}

			char++
		}
	case '*':
		node.Kind = AST_Mul
		char++
	case '/':
		node.Kind = AST_Mul
		char++
	case '%':
		node.Kind = AST_Mul
		char++
	case '^':
		node.Kind = AST_Mul
		char++

	//====== Bitwise ======//
	case '.':
		char++

		switch line[char] {
		case '&':
			node.Kind = AST_BAnd
		case '|':
			node.Kind = AST_BOr
		case '^':
			node.Kind = AST_BXor
		case '<':
			node.Kind = AST_BLeft
		case '>':
			node.Kind = AST_BRight
		default:
			err := fmt.Sprintf("Invalid operator: `%s`", string(line[char-1:char+1]))
			return nil, char, nodes, &Error{err, 25}
		}

		char++
	}

	if char >= len(line) && !slices.Contains([]ASTKind{AST_Inc, AST_Dec}, node.Kind) {
		err := "Expected expression after operator"
		return nil, char, nodes, &Error{err, 26}
	}

	if !slices.Contains([]ASTKind{AST_Inc, AST_Dec}, node.Kind) {
		for unicode.IsSpace(rune(line[char])) && char < len(line) {
			char++
		}

		rhsStart := line[char:]
		rhs, err, charInc := parseLine(rhsStart, 1)
		if err != nil {
			return nil, char, nodes, err
		}
		char += charInc

		nodes = append(nodes, rhs[0])

		if len(nodes) == 0 || nodes == nil || !slices.Contains(append(AST_Num, AST_String, AST_Id), nodes[max(0, len(nodes)-1)].Kind) {
			err := "Expected number or string as RHS of operator"
			return nil, char, nodes, &Error{err, 26}
		}

		node.RHS = nodes[max(0, len(nodes)-1)]
		nodes = nodes[:max(0, len(nodes)-1)]
	}

	nodes = nodes[:max(0, len(nodes)-1)]

	return node, char - 1, nodes, nil
}

func parseEq(line string, char int, nodes []*ASTNode) (*ASTNode, int, []*ASTNode, *Error) {
	node := &ASTNode{}

	if len(nodes) == 0 || nodes == nil ||
		!slices.Contains(append(AST_Num, AST_String, AST_Id, AST_Bool, AST_TypeOf, AST_TypeCast), nodes[max(0, len(nodes)-1)].Kind) {
		err := "Expected typeOf, type cast, bool, ientifier, number, string, identifier or boolean as LHS of equality"
		return nil, char, nodes, &Error{err, 24}
	}

	node.LHS = nodes[max(0, len(nodes)-1)]
	nodes = nodes[:max(0, len(nodes)-1)]

	switch line[char] {
	case '=':
		node.Kind = AST_Assign
		char++
	case '>':
		node.Kind = AST_Greater
		char++
	case '<':
		node.Kind = AST_Lesser
		char++
	}

	if char < len(line) && line[char] == '=' {
		switch line[char-1] {
		case '=':
			node.Kind = AST_Equal
		case '>':
			node.Kind = AST_GreaterOrEqual
		case '<':
			node.Kind = AST_LesserOrEqual
		}

		char++
	}

	if char >= len(line) {
		err := "Expected expression after equality"
		return nil, char, nodes, &Error{err, 26}
	}

	for unicode.IsSpace(rune(line[char])) && char < len(line) {
		char++
	}

	rhsStart := line[char:]
	rhs, err, charInc := parseLine(rhsStart, 1)
	if err != nil {
		return nil, char, nodes, err
	}
	char += charInc

	nodes = append(nodes, rhs[0])

	if len(nodes) == 0 || nodes == nil || !slices.Contains(append(AST_Num, AST_String, AST_Id, AST_Bool, AST_TypeOf, AST_TypeCast), nodes[max(0, len(nodes)-1)].Kind) {
		err := "Expected typeOf, type cast, bool, identifier, number or string as RHS of equality"
		return nil, char, nodes, &Error{err, 26}
	}

	node.RHS = nodes[max(0, len(nodes)-1)]
	nodes = nodes[:max(0, len(nodes)-1)]

	return node, char, nodes, nil
}

func parseNot(line string, char int, nodes []*ASTNode) (*ASTNode, int, []*ASTNode, *Error) {
	node := &ASTNode{}

	node.Kind = AST_Not
	char++

	if char < len(line) && line[char] == '=' {
		node.Kind = AST_NotEqual

		char++
	}

	if node.Kind == AST_NotEqual {
		if !slices.Contains(append(AST_Num, AST_String, AST_Id, AST_Bool), nodes[max(0, len(nodes)-1)].Kind) {
			err := "Expected bool, identifier, number or string as LHS of equality"
			return nil, char, nodes, &Error{err, 24}
		}

		node.LHS = nodes[max(0, len(nodes)-1)]
		nodes = nodes[:max(0, len(nodes)-1)]
	}

	if char >= len(line) {
		err := "Expected expression"
		return nil, char, nodes, &Error{err, 26}
	}

	for unicode.IsSpace(rune(line[char])) && char < len(line) {
		char++
	}

	rhsStart := line[char:]
	rhs, err, charInc := parseLine(rhsStart, 1)
	if err != nil {
		return nil, char, nodes, err
	}
	char += charInc

	nodes = append(nodes, rhs[0])

	if nodes == nil {
		err := "Expected expression"
		return nil, char, nodes, &Error{err, 26}
	} else if !slices.Contains(append(AST_Num, AST_String, AST_Id, AST_Bool), nodes[max(0, len(nodes)-1)].Kind) &&
		node.Kind == AST_NotEqual {
		err := "Expected bool, identifier, number or string as RHS of equality"
		return nil, char, nodes, &Error{err, 24}
	} else if nodes[max(0, len(nodes)-1)].Kind != AST_Bool && node.Kind == AST_Not {
		err := "Expected bool as RHS of `not`"
		return nil, char, nodes, &Error{err, 24}
	}

	node.RHS = nodes[max(0, len(nodes)-1)]
	nodes = nodes[:max(0, len(nodes)-1)]

	return node, char, nodes, nil
}

func parseTypeOp(line string, char int, nodes []*ASTNode) (*ASTNode, int, []*ASTNode, *Error) {
	node := &ASTNode{}

	if nodes != nil && nodes[max(0, len(nodes)-1)].Kind != AST_Id {
		err := "Expected identifier as LHS of type cast or `typeOf`"
		return nil, char, nodes, &Error{err, 24}
	}

	node.LHS = nodes[max(0, len(nodes)-1)]
	nodes = nodes[:max(0, len(nodes)-1)]

	node.Kind = AST_TypeOf
	char++

	if char >= len(line) || char < len(line) && line[char] != ':' {
		err := "Expected another `:`"
		return nil, char, nodes, &Error{err, 27}
	}

	char++

	for char < len(line) && unicode.IsSpace(rune(line[char])) {
		char++
	}

	if char < len(line) {
		rhsStart := line[char:]
		rhs, err, charInc := parseLine(rhsStart, 1)
		if err != nil {
			return nil, char, nodes, err
		}

		nodes = append(nodes, rhs[0])

		if nodes != nil && nodes[max(0, len(nodes)-1)].Kind == AST_Id {
			node.Kind = AST_TypeCast

			char += charInc
			node.RHS = nodes[max(0, len(nodes)-1)]
		} else if nodes != nil &&
			!slices.Contains([]ASTKind{
				AST_Equal,
				AST_NotEqual,
				AST_Greater,
				AST_GreaterOrEqual,
				AST_Lesser,
				AST_LesserOrEqual,
			}, nodes[max(0, len(nodes)-1)].Kind) {
			err := "Expected identifier as RHS of type cast"
			return nil, char, nodes, &Error{err, 24}
		}

		char--
		nodes = nodes[:max(0, len(nodes)-1)]
	}

	return node, char, nodes, nil
}
