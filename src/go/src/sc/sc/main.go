package main

import (
	"fmt"
	"os"

	"css"
	"ltx"
)

var (
	basedir string
)

func main() {
	if len(os.Args) < 3 {
		fmt.Println("Run `main <name of stylesheet> <name of html file>`.")
		os.Exit(0)
	}

	tmpdir, err := css.Run(os.Args[1], os.Args[2])
	if err != nil {
		fmt.Println(err)
		os.Exit(-1)
	}
	ltx.Run(basedir, tmpdir)
}
