package main

import (
	"css"
	"fmt"
	"os"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Run `main <name of stylesheet>`.")
		os.Exit(0)
	}

	c := css.Run(os.Args[1])
	if false {
		fmt.Println(c)
	}
}
