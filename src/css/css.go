package css

import (
	"fmt"
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
	pagearea  map[string][]qrule
	margin    string
	papersize string
}

type CSS struct {
	Stylesheet   sBlock
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
func consumeBlock(toks tokenstream) sBlock {
	// This is the whole block between the opening { and closing }
	i := 0
	start := 0
	colon := 0
	b := sBlock{}
	for {
		// There are only two cases: a key-value rule or something with
		// curly braces
		if t := toks[i]; t.Type == scanner.Delim {
			switch t.Value {
			case ":":
				colon = i
			case ";":
				b.Rules = append(b.Rules, qrule{Key: toks[start:colon], Value: toks[colon+1 : i]})
				start = i + 1
			case "{":
				var nb sBlock
				l := findClosingBrace(toks[i+1:])
				nb = consumeBlock(toks[i+1 : i+l])
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
			}
		}
		i++
		if i == len(toks) {
			break
		}
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
		case "margin":
			pg.margin = v.Value.String()
		case "size":
			pg.papersize = v.Value.String()
		}
	}
	for _, rule := range block.ChildAtRules {
		pg.pagearea[rule.Name] = rule.Rules
	}
	c.Pages[selector] = pg
}

func (c *CSS) dothings() {
	c.Fontfamilies = make(map[string]FontFamily)
	c.Pages = make(map[string]cssPage)
	for _, atrule := range c.Stylesheet.ChildAtRules {
		switch atrule.Name {
		case "font-face":
			c.doFontFace(atrule.Rules)
		case "page":
			c.doPage(atrule)
		}
	}
}

func Run(filename string) *CSS {
	toks := parseCSSFile(filename)
	c := CSS{Stylesheet: consumeBlock(toks)}
	c.dothings()
	return &c
}
