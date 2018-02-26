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

func stringValue(toks tokenstream) string {
	ret := []string{}
	for _, tok := range toks {
		switch tok.Type {
		case scanner.Ident, scanner.Dimension, scanner.String:
			ret = append(ret, tok.Value)
		case scanner.Percentage:
			ret = append(ret, tok.Value+"%")
		case scanner.Hash:
			ret = append(ret, "#"+tok.Value)
		case scanner.Delim:
			switch tok.Value {
			case ";":
				// ignore
			default:
				w("unhandled delimiter", tok)
			}
		default:
			w("unhandled token", tok)
		}
	}
	return strings.Join(ret, " ")
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
				default:
					w("unknown delimiter", tok.Value)

				}
			}
			i = i + 1
			if i == len(tokens) {
				break
			}
		}
		val = tokens[colon:i]
		sel.SetAttr(stringValue(key), stringValue(val))
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
		fmt.Println(lvindent, "},")
	}
}

func (c *CSS) dumpTree() {
	c.document.Each(resolveStyle)

	for _, block := range c.Stylesheet.Blocks {
		selector := block.ComponentValues.String()
		selector = strings.Replace(selector, " ", "", -1)
		x := c.document.Find(selector)
		for _, rule := range block.Rules {
			x.SetAttr(stringValue(rule.Key), stringValue(rule.Value))
		}
	}
	elt := c.document.Find(":root > body")
	fmt.Printf("csshtmltree = {\n")
	c.dump_fonts()
	c.dump_pages()
	elt.Each(fun)
	fmt.Println("}")
}

func (c *CSS) dump_pages() {
	fmt.Println("  pages = {")
	for k, v := range c.Pages {
		if k == "" {
			k = "*"
		}
		fmt.Printf("    [%q] = {\n", k)
		m1k, m1v, m2k, m2v, m3k, m3v, m4k, m4v := fourValues("margin", v.margin)
		fmt.Printf("       [%q]=%q, [%q]=%q,  [%q]=%q,  [%q]=%q,\n", m1k, m1v, m2k, m2v, m3k, m3v, m4k, m4v)
		wd, ht := papersize(v.papersize)
		fmt.Printf("       width = %q, height = %q,\n", wd, ht)
		for paname, parea := range v.pagearea {
			fmt.Printf("       [%q] = {\n", paname)
			for _, rule := range parea {
				fmt.Printf("           [%q] = %q ,\n", rule.Key, stringValue(rule.Value))
			}
			fmt.Println("       },")
		}
		fmt.Println("     },")
	}

	fmt.Println("  },")
}

func (c *CSS) dump_fonts() {
	fmt.Println(" fontfamilies = {")
	for name, ff := range c.Fontfamilies {
		fmt.Printf("     [%q] = { regular = %q, bold=%q, bolditalic=%q, italic=%q },\n", name, ff.Regular, ff.Bold, ff.BoldItalic, ff.Italic)
	}
	fmt.Println(" },")
}

func fourValues(typ string, value string) (string, string, string, string, string, string, string, string) {
	return typ + "-top", value, typ + "-left", value, typ + "-bottom", value, typ + "-right", value
}

func papersize(typ string) (string, string) {
	switch typ {
	case "a5":
		return "148mm", "210mm"
	}
	return "210mm", "297mm"
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
