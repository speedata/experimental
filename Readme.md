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

