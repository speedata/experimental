module main

replace sc/sc v0.0.0 => ./src/go/sc/sc

replace css v0.0.0 => ./src/go/css

replace internal/github-css/scanner v0.0.0 => ./src/go/css/internal/github-css/scanner

go 1.12

require (
	internal/github-css/scanner v0.0.0 // indirect
	sc/sc v0.0.0 // indirect
)
