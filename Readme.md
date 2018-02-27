# Experimental typesetting repository

This repository will contain some experiments with HTML, CSS and print.
The aim is to create a prototype that shows a way to typeset CSS based XML/HTML documents with LuaTeX.

This might turn out as a waste of time, so don't bother having a closer look.

## How it should work

1. Take the most basic examples from https://print-css.rocks/ (lesson basic)
1. Read the CSS files, read the HTML file parse the HTML tree (with the inline CSS)
1. Apply the CSS rules to each node and dump the DOM as a Lua table
1. Run LuaTeX with this table as an input file
1. Typeset according the rules given in the tree


## Steps to get this running

Beware! This is an experiment, totally pre alpha, and you might find out that it was a waste of time. But anyhow, here it is:

1. Get this repository (`git clone https://github.com/speedata/experimental.git`), `cd experimental`
1. Update dependencies and compile with rake: `rake update`
1. Run the software: `bin/sc minimal.css minimal.html` with a really minimal css and html file

You need: [Go](https://golang.org/), [Rake](https://github.com/ruby/rake) and [LuaTeX](https://www.tug.org/texlive/) installed. Once this gets more mature, I will provide ready to run packages.


## Contact

gundlach@speedata.de

