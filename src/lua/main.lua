tex.draftmode=0
tex.enableprimitives('',tex.extraprimitives ())

-- tex.outputmode is only active with new primitives.
tex.outputmode=1
print()

wd = os.getenv("SPWD")

dofile(wd .. "/table.lua")
local page = require("page")
local fonts = require("fonts")
onecm = tex.sp("1cm")
-- factor = 65781
factor = 2^16


glue_spec_node = node.id("glue_spec")
glue_node      = node.id("glue")
glyph_node     = node.id("glyph")
disc_node      = node.id("disc")
rule_node      = node.id("rule")
penalty_node   = node.id("penalty")
whatsit_node   = node.id("whatsit")
hlist_node     = node.id("hlist")
vlist_node     = node.id("vlist")


local thispage = page:new(csshtmltree.pages["*"])


local fontfamilies = { ["sans-serif"] = { regular = {filename =  "texgyreheros-regular.otf" } } }

for ffname,fftable in pairs(csshtmltree.fontfamilies) do
    local tbl = {}
    for k,v in pairs(fftable) do
        if v ~= "" then
            tbl[k] = {filename = v}
        end
    end
    fontfamilies[ffname] = tbl
end


-- fontfamilies = {
--   ["sans"] = {
--     ["regular"] = {
--       ["filename"] = "texgyreheros-regular.otf"
--     },
--   },
--   ["Gentium"] = {
--     ["regular"] = {
--       ["filename"] = "Gentium/GentiumPlus-I.ttf"
--     },
--   },
-- }

local body = csshtmltree[1]


function mknodes( text,fontnumber )
	local head,last
	for s in string.utfvalues(text) do
        n = node.new("glyph")
        n.font = fontnumber
        n.char = s
        head,last = node.insert_after(head,last,n)
	end
	return head
end

function add_color( nodelist, colorname )
    local colorstring
    if colorname == "red" then
        colorstring = " 1 0 0 rg "
    else
        w("color not supported yet (remember, this is only a proof-of-concept!)")
        return nodelist
    end
    local colstart = node.new("whatsit","pdf_colorstack")
    local colstop  = node.new("whatsit","pdf_colorstack")
    colstart.data  = colorstring
    colstart.command = 1
    colstart.stack = 0
    colstop.data = ""
    colstop.command = 2
    colstop.stack = 0

    nodelist = node.insert_before(nodelist,nodelist,colstart)
    nodelist = node.insert_after(nodelist,node.tail(nodelist),colstop)
    return nodelist
end

function add_glue( nodelist,head_or_tail,parameter)
    parameter = parameter or {}

    local n = set_glue(nil, parameter)
    n.subtype = parameter.subtype or 0

    if nodelist == nil then return n end

    if head_or_tail=="head" then
        n.next = nodelist
        nodelist.prev = n
        return n
    else
        local last=node.slide(nodelist)
        last.next = n
        n.prev = last
        return nodelist,n
    end
    assert(false,"never reached")
end


function set_glue( gluenode, values )
    local n
    if gluenode == nil then
        n = node.new("glue")
    else
        n = gluenode
    end
    local spec

    if node.has_field(n,"spec") then
        spec = node.new("glue_spec")
        n.spec = spec
    else
        spec = n
    end
    values = values or {}
    for k,v in pairs(values) do
        spec[k] = v
    end
    return n
end

function finish_par( nodelist )
    assert(nodelist)
    node.slide(nodelist)

    local n = node.new("penalty")
    node.set_attribute(n,att_origin,origin_finishpar)
    n.penalty = 10000
    local last = node.slide(nodelist)
    last.next = n
    n.prev = last
    last = n
    n,last = add_glue(n,"tail",{ subtype = 15, width = 0, stretch = 2^16, stretch_order = 2})
end

function getfont( fontfamily, size )
    if not size then print("Size not given") size = tex.sp("10pt")  end
    -- w("getfont %q %q",tostring(fontfamily),tostring(size))
    local fam = fontfamilies[fontfamily or "sans-serif"]
    -- printtable("fam",fam.regular)
    local ok, f = fonts.define_font(fam.regular.filename,tex.sp(size))
    if ok then
        local num = font.define(f)
        fam.regular.fontnumber = num
    else
        print(f)
    end
    return fam.regular.fontnumber
end

function do_linebreak( nodelist,hsize )
    assert(nodelist,"No nodelist found for line breaking.")
    finish_par(nodelist)
    parameters = parameters or {}

    local pdfignoreddimen = -65536000

    local default_parameters = {
        hsize = hsize,
        emergencystretch = 0.1 * hsize,
        hyphenpenalty = 0,
        linepenalty = 10,
        pretolerance = 0,
        tolerance = 2000,
        doublehyphendemerits = 1000,
        pdfeachlineheight = pdfignoreddimen,
        pdfeachlinedepth  = pdfignoreddimen,
        pdflastlinedepth  = pdfignoreddimen,
        pdfignoreddimen   = pdfignoreddimen,
    }
    for k,v in pairs(parameters) do
        default_parameters[k] = v
    end
    local j
	j = tex.linebreak(nodelist,default_parameters)
	return node.vpack(j)
end


-- x,y in scaled points, top left = 0,0
function output_at( nodelist,x,y )
    local glue_horizontal, glue_vertical = node.new(glue_node), node.new(glue_node)
    glue_horizontal.width = x
    local box
    box = node.insert_after(glue_horizontal, glue_horizontal, nodelist)
    box = node.hpack(box)
    glue_vertical.width = y
    box = node.insert_after(glue_vertical,glue_vertical,box)
    box = node.vpack(box)
    thispage.pagebox = box
end

function boxit( box )
    local box = node.hpack(box)

    local rule_width = 0.1
    local wd = box.width                 / factor - rule_width
    local ht = (box.height + box.depth)  / factor - rule_width
    local dp = box.depth                 / factor - rule_width / 2

    local wbox = node.new("whatsit","pdf_literal")
    wbox.data = string.format("q 0.1 G %g w %g %g %g %g re s Q", rule_width, rule_width / 2, -dp, -wd, ht)
    wbox.mode = 0
    -- Draw box at the end so its contents gets "below" it.
    local tmp = node.tail(box.list)
    tmp.next = wbox
    return box
end

function draw_border( nodelist, attributes )
    local box = node.hpack(nodelist)

    local rule_width = 0.1
    local wd = box.width                 / factor - rule_width
    local ht = (box.height + box.depth)  / factor - rule_width
    local dp = box.depth                 / factor - rule_width / 2

    local wbox = node.new("whatsit","pdf_literal")
    local rules = {}
    rules[#rules + 1] = "q"
    if attributes["border-top-style"] and attributes["border-top-style"] ~= "none" then
        rule_width = tex.sp(attributes["border-top-width"] or "1pt") / factor
        rules[#rules + 1] = string.format("0 G %g w %g %g m %g %g l s Q", rule_width, 0 , ht - dp  , -wd, ht - dp )
    end
    if attributes["border-right-style"] and attributes["border-right-style"] ~= "none" then
        rule_width = tex.sp(attributes["border-right-width"] or "1pt") / factor
        rules[#rules + 1] = string.format("0 G %g w %g %g m %g %g l s Q", rule_width, 0 , -dp , 0, ht - dp )
    end
    if attributes["border-bottom-style"] and attributes["border-bottom-style"] ~= "none" then
        rule_width = tex.sp(attributes["border-bottom-width"] or "1pt") / factor
        rules[#rules + 1] = string.format("0 G %g w %g %g m %g %g l s Q", rule_width, 0 , -dp, -wd, -dp)
    end
    if attributes["border-left-style"] and attributes["border-left-style"] ~= "none" then
        rule_width = tex.sp(attributes["border-left-width"] or "1pt") / factor
        rules[#rules + 1] = string.format("0 G %g w %g %g m %g %g l s Q", rule_width, -wd , -dp , -wd, ht - dp )
    end

    rules[#rules + 1] = "Q"
    -- wbox.data = string.format("0.1 G %g w %g %g m %g %g l s Q", rule_width, 0 , -dp , 0, ht + dp)
    wbox.data = table.concat(rules, " ")
    wbox.mode = 0

    local tmp = node.tail(box.list)
    tmp.next = wbox
    return box
end


local stylesstackmetatable = {
    __newindex = function( tbl, idx, value )
        rawset(tbl, idx, value)
        value.pos = #tbl
    end
}

inherited = {
    width = true, curx = true, cury = true,
    ["border-collapse"] = true, ["border-spacing"] = true, ["caption-side"] = true, ["color"] = true, ["direction"] = true, ["empty-cells"] = true, ["font-family"] = true, ["font-size"] = true, ["font-style"] = true, ["font-variant"] = true, ["font-weight"] = true, ["font"] = true, ["letter-spacing"] = true, ["line-height"] = true, ["list-style-image"] = true, ["list-style-position"] = true, ["list-style-type"] = true, ["list-style"] = true, ["orphans"] = true, ["quotes"] = true, ["richness"] = true, ["text-align"] = true, ["text-indent"] = true, ["text-transform"] = true, ["visibility"] = true, ["white-space"] = true, ["widows"] = true, ["word-spacing"] = true
}

local stylesstack = setmetatable({},stylesstackmetatable)
local levelmt = {
    __index = function( tbl,idx )
        if tbl.pos == 1 then return nil end
        if inherited[idx] then
            return stylesstack[tbl.pos - 1][idx]
        else
            return nil
        end
    end
}
local styles = setmetatable({},levelmt)

tex.pagewidth = thispage.width
tex.pageheight = thispage.height


styles.width =  thispage.width - thispage.margin_left - thispage.margin_right
styles.height =  thispage.height - thispage.margin_top - thispage.margin_bottom
styles.curx = thispage.margin_left
styles.cury = thispage.margin_top
styles["font-family"] = "sans-serif"

stylesstack[#stylesstack + 1] = styles

function handle_element( elt )
	local styles = setmetatable({},levelmt)
	local prevwd = stylesstack[#stylesstack].width
	stylesstack[#stylesstack + 1] = styles
	if elt.attributes then
		for i,v in pairs(elt.attributes) do
			styles[i] = v
		end
	end
    local ml,mt = styles["margin-left"], styles["margin-top"]
    if ml then styles.curx = styles.curx + tex.sp(ml) end
    if mt then styles.cury = styles.cury + tex.sp(mt) end

	local wd = styles.width
	if not tonumber(wd) then
		local percent = string.match(wd,"(.*)%%")
		if percent then
			wd = prevwd * tonumber(percent) / 100
			styles.width = wd
		end
	end
	-- w("element %q  width  %gcm",elt.elementname or "<text>" ,styles.width  / onecm)
	for i,v in ipairs(elt) do
		if type(v) == "table" then
			handle_element(v)
		else
            local fontnumber = getfont(styles["font-family"],styles["font-size"])
			nodelist = mknodes(v,fontnumber)
            nodelist = add_color(nodelist,styles["color"])
			nodelist = do_linebreak(nodelist,styles.width)
            nodelist = draw_border(nodelist,styles)
            output_at(nodelist, styles.curx,styles.cury)

		end
	end
	table.remove(stylesstack)
end

handle_element(body)


thispage:addbox()
tex.box[666] = thispage.pagebox

tex.shipout(666)




