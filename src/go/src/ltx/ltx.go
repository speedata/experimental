package ltx

import (
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"path/filepath"
)

func Run(basedir, tmpdir string) {
	os.Setenv("SPWD", tmpdir)
	os.Setenv("SPBASEDIR", basedir)

	cmd := exec.Command("luatex", "--ini", "--lua", filepath.Join(basedir, "src", "lua", "init.lua"), "main.tex")
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		log.Fatal(err)
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		log.Fatal(err)
	}

	go io.Copy(os.Stdout, stdout)
	go io.Copy(os.Stderr, stderr)

	err = cmd.Run()
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println("finished")
}
