package main

import (
	"fmt"
	"io/ioutil"
	"os"

	"css"
	"ltx"
)

var (
	basedir string
)

func dothings() error {
	if len(os.Args) < 3 {
		fmt.Println("Run `main <name of stylesheet> <name of html file>`.")
		os.Exit(0)
	}

	useSystemTemp := false
	var tmpdir string
	if useSystemTemp {
		tmpdir, err := ioutil.TempDir("", "speedata")
		if err != nil {
			return err
		}
		defer os.RemoveAll(tmpdir)
	} else {
		dir, err := os.Getwd()
		if err != nil {
			return err
		}
		tmpdir = dir
	}

	err := css.Run(os.Args[1], os.Args[2], tmpdir)
	if err != nil {
		return err
	}

	ltx.Run(basedir, tmpdir)
	return nil
}

func main() {
	err := dothings()
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
}
