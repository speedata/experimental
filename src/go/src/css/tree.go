package css

import (
	"fmt"
	"golang.org/x/net/html"
	"io"
	"os"
	"regexp"
	"strings"

	"github.com/PuerkitoBio/goquery"
	"github.com/thejerf/css/scanner"
)

var (
	level              int
	out                io.Writer
	dimen              *regexp.Regexp
	style              *regexp.Regexp
	topleftbottomright [4]string
)

func init() {
	topleftbottomright = [...]string{"top", "left", "bottom", "right"}
	dimen = regexp.MustCompile(`px|mm|cm|in|pt|pc|ch|em|ex|lh|rem|0`)
	style = regexp.MustCompile(`none|hidden|dotted|dashed|solid|double|groove|ridge|inset|outset`)
}

func normalizespace(input string) string {
	return strings.Join(strings.Fields(input), " ")
}

func stringValue(toks tokenstream) string {
	ret := []string{}
	for _, tok := range toks {
		switch tok.Type {
		case scanner.Ident, scanner.Dimension, scanner.String, scanner.Number:
			ret = append(ret, tok.Value)
		case scanner.Percentage:
			ret = append(ret, tok.Value+"%")
		case scanner.Hash:
			ret = append(ret, "#"+tok.Value)
		case scanner.Function:
			ret = append(ret, tok.Value+"(")
		case scanner.Delim:
			switch tok.Value {
			case ";":
				// ignore
			case ",", ")":
				ret = append(ret, tok.Value)
			default:
				w("unhandled delimiter", tok)
			}
		default:
			w("unhandled token", tok)
		}
	}
	return strings.Join(ret, " ")
}

// Recurse through the HTML tree and resolve the style attribute
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
			default:
				w("unknown token type", tok.Type)
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

func isDimension(str string) (bool, string) {
	switch str {
	case "thick":
		return true, "2pt"
	case "medium":
		return true, "1pt"
	case "thin":
		return true, "0.5pt"
	}
	return dimen.MatchString(str), str
}
func isBorderStyle(str string) (bool, string) {
	return style.MatchString(str), str
}

// Change "margin: 1cm;" into "margin-left: 1cm; margin-right: 1cm; ..."
func resolveAttributes(attrs []html.Attribute) map[string]string {
	resolved := make(map[string]string)
	// attribute resolving must be in order of appearance. For example the following border-left-style has no effect:
	//    border-left-style: dotted;
	//    border-left: thick green;
	// because the second line overrides the first line (style defaults to "none")

	for _, attr := range attrs {
		switch attr.Key {
		case "margin":
			for _, margin := range topleftbottomright {
				resolved["margin-"+margin] = attr.Val
			}
		case "border":
			// This does not work with colors such as rgb(1 , 2 , 4) which have spaces in them
			for _, part := range strings.Split(attr.Val, " ") {
				for _, border := range topleftbottomright {
					if ok, str := isDimension(part); ok {
						resolved["border-"+border+"-width"] = str
					} else if ok, str := isBorderStyle(part); ok {
						resolved["border-"+border+"-style"] = str
					} else {
						resolved["border-"+border+"-color"] = part
					}
				}
			}
		case "border-top", "border-right", "border-bottom", "border-left":
			for _, part := range strings.Split(attr.Val, " ") {
				if ok, str := isDimension(part); ok {
					resolved[attr.Key+"-width"] = str
				} else if ok, str := isBorderStyle(part); ok {
					resolved[attr.Key+"-style"] = str
				} else {
					resolved[attr.Key+"-color"] = str
				}
			}
		default:
			resolved[attr.Key] = attr.Val
		}
	}
	return resolved
}

func dumpElement(i int, sel *goquery.Selection) {
	lvindent := strings.Repeat(" ", level)
	eltname := goquery.NodeName(sel)
	if eltname == "#text" {
		if txt := normalizespace(sel.Text()); txt != "" {
			fmt.Fprintf(out, "%s  %q,\n", lvindent, txt)
		}
	} else {
		fmt.Fprintf(out, "%s { elementname = %q,\n", lvindent, goquery.NodeName(sel))
		attributes := resolveAttributes(sel.Get(0).Attr)
		fmt.Fprintf(out, "%s   attributes = {", lvindent)
		for key, value := range attributes {
			fmt.Fprintf(out, "[%q] = %q ,", key, value)

		}
		fmt.Fprintln(out, "},")
		level++
		sel.Contents().Each(dumpElement)
		level--
		fmt.Fprintln(out, lvindent, "},")
	}
}

func (c *CSS) dumpTree(outfile io.Writer) {
	c.document.Find(":root > body")
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
	// The 8pt seems to be the default in browsers and copied to CSS paged media.
	elt := c.document.Find(":root > body").SetAttr("margin", "8pt")
	fmt.Fprintf(out, "csshtmltree = {\n")
	c.dump_fonts()
	c.dump_pages()
	elt.Each(dumpElement)
	fmt.Fprintln(out, "}")
}

func (c *CSS) dump_pages() {
	fmt.Fprintln(out, "  pages = {")
	for k, v := range c.Pages {
		if k == "" {
			k = "*"
		}
		fmt.Fprintf(out, "    [%q] = {", k)
		for k, v := range resolveAttributes(v.attributes) {
			fmt.Fprintf(out, "[%q]=%q,", k, v)
		}
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
