package css

import (
	"fmt"
	"os"
	"strings"

	"github.com/PuerkitoBio/goquery"
	"github.com/thejerf/css/scanner"
)

var (
	level int
)

func normalizespace(input string) string {
	return strings.Join(strings.Fields(input), " ")
}

func resolveStyle(i int, sel *goquery.Selection) {
	a, b := sel.Attr("style")
	if b {
		var tokens tokenstream

		s := scanner.New(a)
		for {
			token := s.Next()
			if token.Type == scanner.EOF || token.Type == scanner.Error {
				break
			}
			switch token.Type {
			case scanner.Comment, scanner.S:
				// ignore
			default:
				tokens = append(tokens, token)
			}
		}
		var i int
		var key, val tokenstream
		start := 0
		colon := 0
		for {
			tok := tokens[i]
			switch tok.Type {
			case scanner.Delim:
				switch tok.Value {
				case ":":
					key = tokens[start:i]
					colon = i + 1
				case ";":
					val = tokens[colon:i]
					sel.SetAttr(key.String(), val.String())
					start = i
				}
			}
			i = i + 1
			if i == len(tokens) {
				break
			}
		}
		val = tokens[colon:i]
		sel.SetAttr(key.String(), val.String())
		sel.RemoveAttr("style")
	}
	sel.Children().Each(resolveStyle)
}

func fun(i int, sel *goquery.Selection) {
	lvindent := strings.Repeat(" ", level)
	eltname := goquery.NodeName(sel)
	if eltname == "#text" {
		if txt := normalizespace(sel.Text()); txt != "" {
			fmt.Printf("%s  %q,\n", lvindent, txt)
		}
	} else {
		fmt.Printf("%s { elementname = %q,\n", lvindent, goquery.NodeName(sel))
		attributes := sel.Get(0).Attr
		if len(attributes) > 0 {
			fmt.Printf("%s   attributes = {", lvindent)
			for _, v := range attributes {
				fmt.Printf("[%q] = %q ,", v.Key, v.Val)
			}
			fmt.Println("},")
		}
		level++
		sel.Contents().Each(fun)
		level--
		if level == 0 {
			fmt.Println(lvindent, "}")
		} else {
			fmt.Println(lvindent, "},")
		}
	}
}

func (c *CSS) dumpTree() {
	c.document.Each(resolveStyle)

	for _, block := range c.Stylesheet.Blocks {
		selector := block.ComponentValues.String()
		selector = strings.Replace(selector, " ", "", -1)
		x := c.document.Find(selector)
		for _, rule := range block.Rules {
			x.SetAttr(rule.Key.String(), rule.Value.String())
		}
	}
	elt := c.document.Find(":root > body")
	fmt.Printf("htmltree = ")
	elt.Each(fun)
}

func (c *CSS) openHTMLFile(filename string) error {
	r, err := os.Open(filename)
	if err != nil {
		return err
	}
	c.document, err = goquery.NewDocumentFromReader(r)
	if err != nil {
		return err
	}
	return nil
}
