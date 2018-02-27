package css

import (
	"fmt"
	"io"
	"os"
	"strings"

	"github.com/PuerkitoBio/goquery"
	"github.com/thejerf/css/scanner"
)

var (
	level int
	out   io.Writer
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
			fmt.Fprintf(out, "%s  %q,\n", lvindent, txt)
		}
	} else {
		fmt.Fprintf(out, "%s { elementname = %q,\n", lvindent, goquery.NodeName(sel))
		attributes := sel.Get(0).Attr
		if len(attributes) > 0 {
			fmt.Fprintf(out, "%s   attributes = {", lvindent)
			for _, v := range attributes {
				fmt.Fprintf(out, "[%q] = %q ,", v.Key, v.Val)
			}
			fmt.Fprintln(out, "},")
		}
		level++
		sel.Contents().Each(fun)
		level--
		fmt.Fprintln(out, lvindent, "},")
	}
}

func (c *CSS) dumpTree(outfile io.Writer) {
	out = outfile
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
	fmt.Fprintf(out, "csshtmltree = {\n")
	c.dump_fonts()
	c.dump_pages()
	elt.Each(fun)
	fmt.Fprintln(out, "}")
}

func (c *CSS) dump_pages() {
	fmt.Fprintln(out, "  pages = {")
	for k, v := range c.Pages {
		if k == "" {
			k = "*"
		}
		fmt.Fprintf(out, "    [%q] = {\n", k)
		margintop, margintopvalue, marginleft, marginleftvalue, marginbottom, marginbottomvalue, marginright, marginrightvalue := fourValues("margin", v.margin)
		if v.margintop != "" {
			margintopvalue = v.margintop
		}
		if v.marginleft != "" {
			marginleftvalue = v.marginleft
		}
		if v.marginbottom != "" {
			marginbottomvalue = v.marginbottom
		}
		if v.marginright != "" {
			marginrightvalue = v.marginright
		}
		fmt.Fprintf(out, "       [%q]=%q, [%q]=%q,  [%q]=%q,  [%q]=%q,\n", margintop, margintopvalue, marginleft, marginleftvalue, marginbottom, marginbottomvalue, marginright, marginrightvalue)
		wd, ht := papersize(v.papersize)
		fmt.Fprintf(out, "       width = %q, height = %q,\n", wd, ht)
		for paname, parea := range v.pagearea {
			fmt.Fprintf(out, "       [%q] = {\n", paname)
			for _, rule := range parea {
				fmt.Fprintf(out, "           [%q] = %q ,\n", rule.Key, stringValue(rule.Value))
			}
			fmt.Fprintln(out, "       },")
		}
		fmt.Fprintln(out, "     },")
	}

	fmt.Fprintln(out, "  },")
}

func (c *CSS) dump_fonts() {
	fmt.Fprintln(out, " fontfamilies = {")
	for name, ff := range c.Fontfamilies {
		fmt.Fprintf(out, "     [%q] = { regular = %q, bold=%q, bolditalic=%q, italic=%q },\n", name, ff.Regular, ff.Bold, ff.BoldItalic, ff.Italic)
	}
	fmt.Fprintln(out, " },")
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
