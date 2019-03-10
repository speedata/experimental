package css

import (
	"io/ioutil"
	"log"

	"github.com/thejerf/css/scanner"
)

func parseCSSFile(filename string) tokenstream {
	tokens := parseCSSBody(filename)
	var finalTokens []*scanner.Token

	for i := 0; i < len(tokens); i++ {
		tok := tokens[i]
		if tok.Type == scanner.AtKeyword && tok.Value == "import" {
			importvalue := tokens[i+1]
			toks := parseCSSFile(importvalue.Value)
			finalTokens = append(toks, finalTokens...)
			// hopefully there is no keyword before the semicolon
			for {
				i++
				if i >= len(tokens) {
					break
				}
				if tokens[i].Value == ";" {
					break
				}
			}
		} else {
			finalTokens = append(finalTokens, tok)
		}
	}
	return finalTokens
}

func parseCSSBody(filename string) tokenstream {
	b, err := ioutil.ReadFile(filename)
	if err != nil {
		log.Fatal(err)
	}

	var tokens tokenstream

	s := scanner.New(string(b))
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
	return tokens
}
