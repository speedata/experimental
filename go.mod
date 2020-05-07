module main

require (
	css v0.0.0
	github.com/speedata/css v1.0.1 // indirect
	internal/github-css/scanner v0.0.0 // indirect
	ltx v0.0.0
	sc/sc v0.0.0
)

replace sc/sc v0.0.0 => ./src/go/sc/sc

replace css v0.0.0 => ./src/go/css

replace ltx v0.0.0 => ./src/go/ltx

replace internal/github-css/scanner v0.0.0 => ./src/go/css/internal/github-css/scanner

go 1.12
