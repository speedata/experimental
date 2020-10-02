# CSS parsing and Lua HTML DOM building

This repository will contain some experiments with HTML, CSS DOM building for Lua.
This is the base of the [speedata Publisher's](https://www.speedata.de/) HTML rendering mode.


1. Get this repository (`git clone https://github.com/speedata/experimental.git`), `cd experimental`
1. Update dependencies and compile with rake: `rake build`
1. Run the software: `bin/sc samples/minimal.html`

This creates a Lua table that is a representation of the parsed HTML with CSS applied

You need: [Go](https://golang.org/) >= version 1.11 and [Rake](https://github.com/ruby/rake) installed.
(Actually the `Rakefile` is just provided for convenience, have a look inside it to find out how to compile the software without using Rake.)

You can try it out by installing the speedata Publisher, see the [HTML example](https://github.com/speedata/examples/tree/master/technical/html) as a starting point.


## Contact

gundlach@speedata.de

