package include

import (
	"bufio"
	"fmt"
	"os"
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

		if len(line) == 0 || line[0:2] == "//" {
			lineNum++
			continue
		}

		nodes, err := parseLine(line)
		if err != nil {
			return ASTNode{}, err
		}

		tree = append(tree, nodes...)
		lineNum++
	}

	rootNode.Children = tree

	return rootNode, nil
}

func parseLine(line string) ([]*ASTNode, *Error) {
	line = strings.TrimSpace(line)

	nodes := []*ASTNode{}

	for char := 0; char < len(line); char++ {
		node := &ASTNode{}

		if unicode.IsLetter(rune(line[0])) {
			node.Kind = AST_Id

			for symbol := 0; symbol < len(line) && !unicode.IsSpace(rune(line[symbol])); symbol++ {
				node.Value += string(line[symbol])
				char++
			}
		} else if unicode.IsNumber(rune(line[0])) {
			node.Kind = AST_Int

			for symbol := 0; symbol < len(line) && !unicode.IsSpace(rune(line[symbol])); symbol++ {
				node.Value += string(line[symbol])

				if symbol > 0 && line[symbol-1] == '0' {
					switch line[symbol] {
					case 'x':
						node.Kind = AST_Hex
					case 'b':
						node.Kind = AST_Binary
					}
				} else if unicode.IsLetter(rune(line[symbol])) {
					switch node.Kind {
					case AST_Int:
						node.Kind = AST_Id
					case AST_Binary:
						err := fmt.Sprintf("Invalid symbol found in binary, expected `0` or `1`: `%s`", string(line[symbol]))
						return nil, &Error{err, 20}
					case AST_Hex:
						if !strings.Contains("ABCDEFabcdef", string(line[symbol])) {
							err := fmt.Sprintf("Invalid symbol found in hexadecimal, expected `0-9`, `a-f` or `A-F`: `%s`", string(line[symbol]))
							return nil, &Error{err, 20}
						}
					}
				}

				char++
			}
		} else {
			err := fmt.Sprintf("Invalid symbol: `%s`", string(line[char]))
			return nil, &Error{err, 21}
		}

		nodes = append(nodes, node)
	}

	return nodes, nil
}
