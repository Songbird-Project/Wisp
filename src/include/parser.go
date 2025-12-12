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
	p := &Parser{
		Scanner: *bufio.NewScanner(file),
	}

	for p.Scanner.Scan() {
		line := strings.TrimSpace(p.Scanner.Text())

		if len(line) == 0 || len(line) >= 2 && line[0:2] == "//" {
			lineNum++
			continue
		}

		nodes, err, _ := p.parse(-1, nil)
		if err != nil {
			return ASTNode{}, err
		}

		tree = append(tree, nodes...)
		lineNum++
	}

	rootNode.Children = tree

	return rootNode, nil
}

func (p *Parser) parse(exprs int, toParse *string) ([]*ASTNode, *Error, int) {
	var line string

	if toParse != nil {
		line = *toParse
	} else {
		line = strings.TrimSpace(p.Scanner.Text())
	}

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

			for char < len(line) && unicode.IsLetter(rune(line[char])) {
				node.Value += string(line[char])
				char++
			}

			switch node.Value {
			case "fn":
				if p.Context == AST_Function {
					err := "Expected function name after `fn` keyword"
					return nil, &Error{err, 63}, char
				}

				fnNode, newChar, err := p.parseFn(line, char)
				if err != nil {
					return nil, err, char
				}

				node = fnNode
				char = newChar
			case "return":
			// TODO: `parseReturn` method
			case "exit":
			// TODO: `parseExit` method
			case "true":
				node.Kind = AST_True
				node.Value = ""
			case "false":
				node.Kind = AST_False
				node.Value = ""
			case "nil":
				node.Kind = AST_Nil
				node.Value = ""
			}

			char--
			// Parse numbers
		} else if unicode.IsNumber(rune(line[char])) {
			node.Kind = AST_Int

			for char < len(line) && !unicode.IsSpace(rune(line[char])) {
				node.Value += string(line[char])

				if unicode.IsLetter(rune(line[char])) {
					switch node.Kind {
					case AST_Int:
						node.Kind = AST_Id

						if char > 0 && line[char-1] == '0' {
							switch line[char] {
							case 'x':
								node.Kind = AST_Hex
							case 'b':
								node.Kind = AST_Binary
							}
						}
					case AST_Binary:
						err := fmt.Sprintf("Invalid char found in binary, expected `0` or `1`: `%s`", string(line[char]))
						return nil, &Error{err, 20}, char
					case AST_Hex:
						if !strings.Contains("ABCDEFabcdef", string(line[char])) {
							err := fmt.Sprintf("Invalid char found in hexadecimal, expected `0-9`, `a-f` or `A-F`: `%s`", string(line[char]))
							return nil, &Error{err, 20}, char
						}
					case AST_Float:
						err := fmt.Sprintf("Invalid char in float, expected `0-9`: `%s`", string(line[char]))
						return nil, &Error{err, 21}, char
					}
				} else if line[char] == '.' {
					if char+1 < len(line) && unicode.IsSymbol(rune(line[char+1])) {
						node.Value = node.Value[:len(node.Value)-1]
						char--
						break
					} else if node.Kind == AST_Float {
						err := fmt.Sprintf("Invalid char in float, expected `0-9`: `%s`", string(line[char]))
						return nil, &Error{err, 21}, char
					} else {
						node.Kind = AST_Float
					}
				} else if unicode.IsSymbol(rune(line[char])) || strings.Contains("+-*/^%", string(line[char])) {
					node.Value = node.Value[:len(node.Value)-1]
					char--
					break
				}

				if !unicode.IsSymbol(rune(line[char])) {
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

			for char < len(line) && !strings.Contains("'\"`", string(line[char])) {
				node.Value += string(line[char])
				char++
			}

			if !strings.Contains("'\"`", string(line[char])) {
				err := "Missing string terminator"
				return nil, &Error{err, 23}, char
			}
		} else if strings.Contains("+-*/%^.", string(line[char])) {
			opNode, newChar, newNodes, err := p.parseOp(line, char, nodes)
			if err != nil {
				return nil, err, char
			}

			node = opNode
			char = newChar
			nodes = newNodes
		} else if strings.Contains("=<>", string(line[char])) {
			eqNode, newChar, newNodes, err := p.parseEq(line, char, nodes)
			if err != nil {
				return nil, err, char
			}

			node = eqNode
			char = newChar
			nodes = newNodes
		} else if line[char] == '!' {
			notNode, newChar, newNodes, err := p.parseNot(line, char, nodes)
			if err != nil {
				return nil, err, char
			}

			node = notNode
			char = newChar
			nodes = newNodes
		} else if line[char] == ':' {
			opNode, newChar, newNodes, err := p.parseTypeOp(line, char, nodes)
			if err != nil {
				return nil, err, char
			}

			node = opNode
			char = newChar
			nodes = newNodes
		} else if line[char] == '{' {
			blockNode, newChar, err := p.parseBlock(line, char)
			if err != nil {
				return nil, err, char
			}

			node = blockNode
			char = newChar
		} else if p.Context == AST_Block && line[char] == '}' {
			return nil, nil, char
		} else if line[char] == '(' {
			groupNode, newChar, err := p.parseGroup(line, char)
			if err != nil {
				return nil, err, char
			}

			node = groupNode
			char = newChar
		} else if (p.Context == AST_Function || p.Context == AST_Group) && line[char] == ')' {
			return nil, nil, char
		} else {
			err := fmt.Sprintf("Invalid symbol: `%s`", string(line[char]))
			return nil, &Error{err, 22}, char
		}

		exprs--
		nodes = append(nodes, node)
	}

	for _, node := range nodes {
		fmt.Printf("Value: %s, Kind: %s\n", node.Value, node.Kind)
	}

	return nodes, nil, char
}

func (p *Parser) parseOp(line string, char int, nodes []*ASTNode) (*ASTNode, int, []*ASTNode, *Error) {
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
		node.Kind = AST_Div
		char++
	case '%':
		node.Kind = AST_Mod
		char++
	case '^':
		node.Kind = AST_Pow
		char++

	//====== Bitwise ======//
	case '.':
		char++

		if char >= len(line) {
			err := "Expected operator after bitwise initializer"
			return nil, char, nodes, &Error{err, 25}
		}

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
		rhs, err, charInc := p.parse(1, &rhsStart)
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

func (p *Parser) parseEq(line string, char int, nodes []*ASTNode) (*ASTNode, int, []*ASTNode, *Error) {
	node := &ASTNode{}

	if len(nodes) == 0 || nodes == nil ||
		!slices.Contains(append(append(AST_Num, AST_String, AST_Id, AST_TypeOf, AST_TypeCast), AST_Bool...),
			nodes[max(0, len(nodes)-1)].Kind) {
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
	rhs, err, charInc := p.parse(1, &rhsStart)
	if err != nil {
		return nil, char, nodes, err
	}
	char += charInc

	nodes = append(nodes, rhs[0])

	if len(nodes) == 0 || nodes == nil ||
		!slices.Contains(append(append(AST_Num, AST_String, AST_Id, AST_TypeOf, AST_TypeCast), AST_Bool...),
			nodes[max(0, len(nodes)-1)].Kind) {
		err := "Expected typeOf, type cast, bool, identifier, number or string as RHS of equality"
		return nil, char, nodes, &Error{err, 26}
	}

	node.RHS = nodes[max(0, len(nodes)-1)]
	nodes = nodes[:max(0, len(nodes)-1)]

	return node, char, nodes, nil
}

func (p *Parser) parseNot(line string, char int, nodes []*ASTNode) (*ASTNode, int, []*ASTNode, *Error) {
	node := &ASTNode{}

	node.Kind = AST_Not
	char++

	if char < len(line) && line[char] == '=' {
		node.Kind = AST_NotEqual

		char++
	}

	if node.Kind == AST_NotEqual {
		if !slices.Contains(append(append(AST_Num, AST_String, AST_Id), AST_Bool...), nodes[max(0, len(nodes)-1)].Kind) {
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
	rhs, err, charInc := p.parse(1, &rhsStart)
	if err != nil {
		return nil, char, nodes, err
	}
	char += charInc

	nodes = append(nodes, rhs[0])

	if nodes == nil {
		err := "Expected expression"
		return nil, char, nodes, &Error{err, 26}
	} else if !slices.Contains(append(append(AST_Num, AST_String, AST_Id), AST_Bool...), nodes[max(0, len(nodes)-1)].Kind) &&
		node.Kind == AST_NotEqual {
		err := "Expected bool, identifier, number or string as RHS of equality"
		return nil, char, nodes, &Error{err, 24}
	} else if slices.Contains(AST_Bool, nodes[max(0, len(nodes)-1)].Kind) && node.Kind == AST_Not {
		err := "Expected bool as RHS of `not`"
		return nil, char, nodes, &Error{err, 24}
	}

	node.RHS = nodes[max(0, len(nodes)-1)]
	nodes = nodes[:max(0, len(nodes)-1)]

	return node, char, nodes, nil
}

func (p *Parser) parseTypeOp(line string, char int, nodes []*ASTNode) (*ASTNode, int, []*ASTNode, *Error) {
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
		rhs, err, charInc := p.parse(1, &rhsStart)
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

func (p *Parser) parseFn(line string, char int) (*ASTNode, int, *Error) {
	p.Context = AST_Function

	node := &ASTNode{}
	node.Kind = AST_Function

	loc := line[char:]
	name, err, newChar := p.parse(1, &loc)
	if err != nil {
		return nil, char, err
	}

	if len(name) == 0 || name[0].Kind != AST_Id {
		err := "Expected identifier for function name"
		return nil, char, &Error{err, 27}
	}

	node.Value = name[0].Value
	char += newChar

	for char < len(line) && unicode.IsSpace(rune(line[char])) {
		char++
	}

	params, newChar, err := p.parseGroup(line, char)
	if err != nil {
		return nil, char, err
	}

	node.Params = params.Params
	char = newChar

	for char < len(line) && unicode.IsSpace(rune(line[char])) {
		char++
	}

	block, newChar, err := p.parseBlock(line, char)
	if err != nil {
		return nil, char, err
	}

	node.Children = block.Children
	char = newChar

	p.Context = AST_Nil

	return node, char, nil
}

func (p *Parser) parseBlock(line string, char int) (*ASTNode, int, *Error) {
	node := &ASTNode{}
	node.Kind = AST_Block
	node.Children = []*ASTNode{}

	if line[char] != '{' {
		err := fmt.Sprintf("Invalid open block: %s", string(line[char]))
		return nil, char, &Error{err, 28}
	}
	char++

	p.Context = AST_Block

	for char < len(line) && line[char] != '}' {
		for char < len(line) && unicode.IsSpace(rune(line[char])) {
			char++
		}

		if char >= len(line) {
			if !p.Scanner.Scan() {
				err := "Unexpected EOF in block"
				return nil, char, &Error{err, 28}
			}
			line = p.Scanner.Text()
			char = 0
			continue
		}

		if line[char] == '}' {
			break
		}

		loc := line[char:]
		nodes, err, newChar := p.parse(-1, &loc)
		if err != nil {
			return nil, char, err
		}

		char += newChar

		node.Children = append(node.Children, nodes...)
	}

	if char >= len(line) || line[char] != '}' {
		err := "Missing closing `}` in block"
		return nil, char, &Error{err, 28}
	}

	for char < len(line) && unicode.IsSpace(rune(line[char])) {
		char++
	}

	p.Context = AST_Nil
	char++

	return node, char, nil
}

func (p *Parser) parseGroup(line string, char int) (*ASTNode, int, *Error) {
	node := &ASTNode{}
	node.Kind = AST_Group
	node.Params = [][]*ASTNode{}

	if line[char] != '(' {
		err := fmt.Sprintf("Invalid open group: %s", string(line[char]))
		return nil, char, &Error{err, 28}
	}
	char++

	if p.Context == AST_Nil {
		p.Context = AST_Group
	}

	for {
		for char < len(line) && unicode.IsSpace(rune(line[char])) {
			char++
		}

		if char >= len(line) {
			if !p.Scanner.Scan() {
				err := "Unexpected EOF in group"
				return nil, char, &Error{err, 28}
			}

			line = p.Scanner.Text()
			char = 0
			continue
		}

		if line[char] == ')' {
			break
		}

		exprs := -1
		if p.Context == AST_Function {
			exprs = 2
		}

		loc := line[char:]
		param, err, newChar := p.parse(exprs, &loc)
		if err != nil {
			return nil, char, err
		}

		if p.Context == AST_Function &&
			(len(param) != 2 ||
				(len(param) == 2 &&
					(param[0].Kind != AST_Id || param[1].Kind != AST_Id))) {
			err := "Expected name and type for function parameter"
			return nil, char, &Error{err, 28}
		}

		for char < len(line) && unicode.IsSpace(rune(line[char])) {
			char++
		}

		char += newChar

		node.Params = append(node.Params, param)
	}

	if char >= len(line) || line[char] != ')' {
		err := "Missing closing `)` in group"
		return nil, char, &Error{err, 28}
	}

	p.Context = AST_Nil
	char++

	return node, char, nil
}
