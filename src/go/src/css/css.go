package css

import (
	"fmt"
	"golang.org/x/net/html"
	"os"
	"path/filepath"

	"github.com/PuerkitoBio/goquery"
	"github.com/thejerf/css/scanner"
)

func init() {
	if false {
		fmt.Println("dummy")
	}
}

type tokenstream []*scanner.Token

type qrule struct {
	Key   tokenstream
	Value tokenstream
}

type sBlock struct {
	Name            string      // only set if this is an at-rule
	ComponentValues tokenstream // the "selector"
	ChildAtRules    []*sBlock   // the block's at-rules, if any
	Blocks          []*sBlock   // the at-rule's blocks, if any
	Rules           []qrule     // the key-value pairs
}

type cssPage struct {
	pagearea   map[string][]qrule
	attributes []html.Attribute
	papersize  string
}

type CSS struct {
	document     *goquery.Document
	Stylesheet   []sBlock
	Fontfamilies map[string]FontFamily
	Pages        map[string]cssPage
}

type FontFamily struct {
	Regular    string
	Bold       string
	Italic     string
	BoldItalic string
}

// Return the position of th matching closing brace "}"
func findClosingBrace(toks tokenstream) int {
	level := 1
	for i, t := range toks {
		if t.Type == scanner.Delim {
			switch t.Value {
			case "{":
				level++
			case "}":
				level--
				if level == 0 {
					return i + 1
				}
			}
		}
	}
	return len(toks)
}

// Get the contents of a block. The name (in case of an at-rule)
// and the selector will be added later on
func consumeBlock(toks tokenstream, inblock bool) sBlock {
	// This is the whole block between the opening { and closing }
	b := sBlock{}
	if len(toks) == 0 {
		return b
	}
	i := 0
	start := 0
	colon := 0
	for {
		// There are only two cases: a key-value rule or something with
		// curly braces
		if t := toks[i]; t.Type == scanner.Delim {
			switch t.Value {
			case ":":
				if inblock {
					colon = i
				}
			case ";":
				b.Rules = append(b.Rules, qrule{Key: toks[start:colon], Value: toks[colon+1 : i]})
				colon = 0
				start = i + 1
			case "{":
				var nb sBlock
				l := findClosingBrace(toks[i+1:])
				nb = consumeBlock(toks[i+1:i+l], true)
				if toks[start].Type == scanner.AtKeyword {
					nb.Name = toks[start].Value
					b.ChildAtRules = append(b.ChildAtRules, &nb)
					nb.ComponentValues = toks[start+1 : i]
				} else {
					b.Blocks = append(b.Blocks, &nb)
					nb.ComponentValues = toks[start:i]
				}
				i = i + l
				start = i + 1
			default:
				// w("unknown delimiter", t.Value)
			}
		}
		i++
		if i == len(toks) {
			break
		}
	}
	if colon > 0 {
		b.Rules = append(b.Rules, qrule{Key: toks[start:colon], Value: toks[colon+1 : len(toks)]})
	}
	return b
}

func (c *CSS) doFontFace(ff []qrule) {
	var fontfamily, fontstyle, fontweight, fontsource string
	for _, rule := range ff {
		switch rule.Key.String() {
		case "font-family":
			fontfamily = rule.Value.String()
		case "font-style":
			fontstyle = rule.Value.String()
		case "font-weight":
			fontweight = rule.Value.String()
		case "src":
			for _, v := range rule.Value {
				if v.Type == scanner.URI {
					fontsource = v.Value
					break
				}
			}
		}
	}
	fam := c.Fontfamilies[fontfamily]
	if fontweight == "bold" {
		if fontstyle == "italic" {
			fam.BoldItalic = fontsource
		} else {
			fam.Bold = fontsource
		}
	} else {
		if fontstyle == "italic" {
			fam.Italic = fontsource
		} else {
			fam.Regular = fontsource
		}
	}
	c.Fontfamilies[fontfamily] = fam
}

func (c *CSS) doPage(block *sBlock) {
	selector := block.ComponentValues.String()
	pg := c.Pages[selector]
	if pg.pagearea == nil {
		pg.pagearea = make(map[string][]qrule)
	}
	for _, v := range block.Rules {
		switch v.Key.String() {
		case "size":
			pg.papersize = v.Value.String()
		default:
			a := html.Attribute{Key: v.Key.String(), Val: stringValue(v.Value)}
			pg.attributes = append(pg.attributes, a)
		}
	}
	for _, rule := range block.ChildAtRules {
		pg.pagearea[rule.Name] = rule.Rules
	}
	c.Pages[selector] = pg
}

func (c *CSS) processAtRules() {
	c.Fontfamilies = make(map[string]FontFamily)
	c.Pages = make(map[string]cssPage)
	for _, stylesheet := range c.Stylesheet {
		for _, atrule := range stylesheet.ChildAtRules {
			switch atrule.Name {
			case "font-face":
				c.doFontFace(atrule.Rules)
			case "page":
				c.doPage(atrule)
			}
		}

	}
}

func Run(tmpdir string, arguments []string) error {
	var err error
	curwd, err := os.Getwd()
	if err != nil {
		return err
	}
	c := CSS{}
	c.Stylesheet = append(c.Stylesheet, consumeBlock(parseCSSFile("defaultstyles.css"), false))
	htmlfilename := arguments[1]
	// read additional stylesheets given on the command line
	for i := 2; i < len(arguments); i++ {
		c.Stylesheet = append(c.Stylesheet, consumeBlock(parseCSSFile(arguments[i]), false))
	}

	fn := filepath.Base(htmlfilename)
	p, err := filepath.Abs(filepath.Dir(htmlfilename))
	if err != nil {
		return err
	}

	os.Chdir(p)
	defer os.Chdir(curwd)
	err = c.openHTMLFile(fn)
	if err != nil {
		return err
	}
	c.processAtRules()

	outfile, err := os.Create(filepath.Join(tmpdir, "table.lua"))
	if err != nil {
		return err
	}
	c.dumpTree(outfile)
	outfile.Close()
	return nil
}
