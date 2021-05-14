package main

import (
	"fmt"
	"io/ioutil"
	"os"

	"experimental/css"
)

var (
	basedir string
)

func filefinder(filename string) string {
	return filename
}

func dothings() error {
	if len(os.Args) < 2 {
		fmt.Println("Run `main <file.html> [stylesheet.css ... ] `.")
		os.Exit(0)
	}
	c := css.NewCssParser(filefinder)
	str, err := c.Run(os.Args[1:])
	if err != nil {
		return err
	}

	fn := "table.lua"

	err = ioutil.WriteFile(fn, []byte(str), 0644)
	if err != nil {
		return err
	}
	return nil
}

func main() {
	err := dothings()
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
}
