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

// func httpreader(filename string) (io.ReadCloser, error) {
// 	fmt.Println("** file finder", filename)

// 	return filename, nil
// }

func dothings() error {
	if len(os.Args) < 2 {
		fmt.Println("Run `main <file.html>`.")
		os.Exit(0)
	}
	c := css.NewCssParser()
	str, err := c.Run(os.Args[1])
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
