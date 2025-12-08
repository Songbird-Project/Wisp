package main

import (
	"fmt"
	"os"

	"github.com/Songbird-Project/wisp/include"
)

func main() {
	astTree, err := include.GenerateAST()
	if err != nil {
		fmt.Printf("%s\n", err.Info)
		os.Exit(err.ExitCode)
	}

	for _, node := range astTree.Children {
		fmt.Printf("Value: %s, Kind: %s\n", node.Value, node.Kind)
	}
}
