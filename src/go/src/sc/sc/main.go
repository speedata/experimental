package main

import (
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"

	"css"
	"ltx"
)

var (
	basedir string
)

func dothings() error {
	if len(os.Args) < 2 {
		fmt.Println("Run `main <file.html> [stylesheet.css ... ] `.")
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

	err := css.Run(tmpdir, os.Args)
	if err != nil {
		return err
	}

	ltx.Run(basedir, filepath.Join(tmpdir, "table.lua"))
	return nil
}

func main() {
	err := dothings()
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
}
