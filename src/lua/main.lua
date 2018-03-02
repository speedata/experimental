tex.draftmode=0
tex.enableprimitives('',tex.extraprimitives ())
-- Lua 5.2 has table.unpack
unpack = unpack or table.unpack

-- tex.outputmode is only active with new primitives.
tex.outputmode=1
print()

wd = os.getenv("SPWD")

dofile(wd .. "/table.lua")
local page = require("page")
local fonts = require("fonts")
onecm = tex.sp("1cm")
factor = 65781
-- factor = 2^16


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

--- Round the given `numb` to `idp` digits. From [the Lua wiki](http://lua-users.org/wiki/SimpleRound)
function math.round(num, idp)
  if idp and idp>0 then
    local mult = 10^idp
    return math.floor(num * mult + 0.5) / mult
  end
  return math.floor(num + 0.5)
end

--- Convert scaled point to postscript points,
--- rounded to three digits after decimal point
function sp_to_bp( sp )
  return math.round(sp / factor , 3)
end


local orig_texsp = tex.sp
function tex.sp( number_or_string )
    if number_or_string == "0" then return 0 end
  if type(number_or_string) == "string" then
    local tmp = string.gsub(number_or_string,"(%d)pt","%1bp"):gsub("(%d)pp","%1pt")
    local ret = { pcall(orig_texsp,tmp) }
    if ret[1]==false then
      w("Could not convert dimension %q",number_or_string)
      return nil
    end
    return unpack(ret,2)
  end
  return orig_texsp(number_or_string)
end


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

function color_pdf_string( colorname )
    local colorstring
    if colorname == "red" then
        colorstring = "1 0 0 rg 1 0 0 RG"
    elseif colorname == "blue" then
        colorstring = "0 0 1 rg 0 0 1 RG"
    elseif colorname == "black" then
        colorstring = "0 g 0 G"
    else
        w("color %q not supported yet (remember, this is only a proof-of-concept!)", tostring(colorname))
        colorstring = "0 g 0 G"
    end
    return colorstring
end

function add_color( nodelist, colorname )
    local colorstring = color_pdf_string(colorname)
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
    local gluebordertop    = node.new(glue_node)
    local glueborderright  = node.new(glue_node)
    local glueborderbottom = node.new(glue_node)
    local glueborderleft   = node.new(glue_node)


    local padding_top, padding_right, padding_bottom, padding_left = 0,0,0,0
    if attributes["padding-top"] then padding_top = tex.sp(attributes["padding-top"]) end
    if attributes["padding-right"] then padding_right = tex.sp(attributes["padding-right"]) end
    if attributes["padding-bottom"] then padding_bottom = tex.sp(attributes["padding-bottom"]) end
    if attributes["padding-left"] then padding_left = tex.sp(attributes["padding-left"]) end

    local margin_top, margin_right, margin_bottom, margin_left = 0,0,0,0
    if attributes["margin-top"] then margin_top = tex.sp(attributes["margin-top"]) end
    if attributes["margin-right"] then margin_right = tex.sp(attributes["margin-right"]) end
    if attributes["margin-bottom"] then margin_bottom = tex.sp(attributes["margin-bottom"]) end
    if attributes["margin-left"] then margin_left = tex.sp(attributes["margin-left"]) end

    local rule_width_top, rule_width_right, rule_width_bottom, rule_width_left = 0,0,0,0
    if attributes["border-top-style"] and attributes["border-top-style"] ~= "none" then
        rule_width_top = tex.sp(attributes["border-top-width"] or 0)
    end
    if attributes["border-right-style"] and attributes["border-right-style"] ~= "none" then
        rule_width_right = tex.sp(attributes["border-right-width"] or 0)
    end
    if attributes["border-bottom-style"] and attributes["border-bottom-style"] ~= "none" then
        rule_width_bottom = tex.sp(attributes["border-bottom-width"] or 0)
    end
    if attributes["border-left-style"] and attributes["border-left-style"] ~= "none" then
        rule_width_left = tex.sp(attributes["border-left-width"] or 0)
    end

    gluebordertop.width    = rule_width_top    + padding_top + margin_top
    glueborderright.width  = rule_width_right  + padding_right + margin_right
    glueborderbottom.width = rule_width_bottom + padding_bottom + margin_bottom
    glueborderleft.width   = rule_width_left   + padding_left + margin_left

    local wd, wd_bp = nodelist.width,  nodelist.width   / factor
    local ht, ht_bp = nodelist.height, nodelist.height  / factor
    local dp, dp_bp = nodelist.depth,  nodelist.depth   / factor

    local rule_width_bp, shift_up_bp, shift_right_bp
    local colorstring = "0.5 G"

    local rules = {}
    rules[#rules + 1] = "q"
    -- 4 trapezoids (1 for each border)
    local x1, x2, x2, x4, y1, y2, y3, y4
    if rule_width_top > 0 then
        colorstring = color_pdf_string(attributes["border-top-color"])
        x4 = margin_left / factor
        x1 = (rule_width_left + margin_left) / factor
        x2 = x1 + wd_bp + (padding_left + padding_right ) / factor
        x3 = x2 + rule_width_right / factor

        y1 = (rule_width_bottom + ht + dp + padding_bottom + padding_top + margin_bottom) / factor
        y2 = y1
        y3 = y2 + rule_width_top / factor
        y4 = y3
        rules[#rules + 1] = string.format("%s 0 w %g %g m %g %g l %g %g l %g %g l h f", colorstring,  x1,y1,x2,y2, x3,y3, x4,y4)
    end
    if attributes["border-right-style"] and attributes["border-right-style"] ~= "none" then
        colorstring = color_pdf_string(attributes["border-right-color"])
        x1 = ( rule_width_left + wd + padding_left + padding_right + margin_left) / factor
        x2 = x1 + rule_width_right / factor
        x3 = x2
        x4 = x1

        y2 = margin_bottom / factor
        y1 = y2 + ( rule_width_bottom ) / factor
        y4 = y1 + ht_bp + dp_bp + (padding_bottom + padding_top) / factor
        y3 = y4 + rule_width_top / factor
        rules[#rules + 1] = string.format("%s 0 w %g %g m %g %g l %g %g l %g %g l h f", colorstring,  x1,y1,x2,y2, x3,y3, x4,y4)
    end
    if attributes["border-bottom-style"] and attributes["border-bottom-style"] ~= "none" then
        colorstring = color_pdf_string(attributes["border-bottom-color"])
        x1 = margin_left / factor
        x4 = x1 + rule_width_left / factor
        x3 = x4 + wd_bp  + (padding_left + padding_right ) / factor
        x2 = x3 + rule_width_right / factor

        y1 = margin_bottom / factor
        y2 = y1
        y3 = y2 + rule_width_bottom / factor
        y4 = y3
        rules[#rules + 1] = string.format("%s 0 w %g %g m %g %g l %g %g l %g %g l h f", colorstring,  x1,y1,x2,y2, x3,y3, x4,y4)
    end
    if attributes["border-left-style"] and attributes["border-left-style"] ~= "none" then
        colorstring = color_pdf_string(attributes["border-left-color"])
        x1 = sp_to_bp(margin_left)
        x4 = x1
        x2 = x1 + sp_to_bp(rule_width_left)
        x3 = x2

        y1 = sp_to_bp(margin_bottom)
        y2 = y1 + sp_to_bp(rule_width_bottom)
        y3 = y2 + ht_bp + dp_bp + (padding_bottom + padding_top) / factor
        y4 = y3 + rule_width_top / factor
        rules[#rules + 1] = string.format("%s 0 w %g %g m %g %g l %g %g l %g %g l h f", colorstring,  x1,y1,x2,y2, x3,y3, x4,y4)
    end
    rules[#rules + 1] = "Q"


    local wbox = node.new("whatsit","pdf_literal")
    wbox.data = table.concat(rules, " ")
    wbox.mode = 0

    nodelist = node.insert_before(nodelist,nodelist,glueborderleft)
    nodelist = node.insert_after(nodelist,node.tail(nodelist),glueborderright)
    local box = node.hpack(nodelist)
    box = node.insert_before(box,box,gluebordertop)
    box = node.insert_after(box,node.tail(box),glueborderbottom)
    box = node.insert_after(box,node.tail(box),wbox)
    box = node.vpack(box)

    return box
end


local stylesstackmetatable = {
    __newindex = function( tbl, idx, value )
        rawset(tbl, idx, value)
        value.pos = #tbl
    end
}

inherited = {
    width = false, curx = true, cury = true,
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
styles.color = "black"
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

    local margin_left   = styles["margin-left"]  or 0
    local margin_right  = styles["margin-right"] or 0
    local margin_top    = styles["margin-top"] or 0
    local padding_left  = styles["padding-left"]       or 0
    local padding_right = styles["padding-right"]      or 0
    local border_left   = styles["border-left-width"]  or 0
    local border_top    = styles["border-top-width"]   or 0
    local border_right  = styles["border-right-width"] or 0

    local wd = styles.width or "auto"
    if wd == "auto" then
        styles.width = prevwd
        styles.width = styles.width - tex.sp(margin_left) - tex.sp(margin_right) - tex.sp(padding_left) - tex.sp(padding_right) - tex.sp(border_left) - tex.sp(border_right)
	elseif not tonumber(wd) then
		local percent = string.match(wd,"(.*)%%")
		if percent then
			wd = prevwd * tonumber(percent) / 100
			styles.width = wd
		end
    else
        w("unhandled width")
	end
	-- w("element %q  width  %gcm",elt.elementname or "<text>" ,styles.width  / onecm)
	for i,v in ipairs(elt) do
		if type(v) == "table" then
            styles.curx = styles.curx + tex.sp(margin_left) + tex.sp(border_left)
            styles.cury = styles.cury + tex.sp(margin_top)  + tex.sp(border_top)
			handle_element(v)
		else
            local fontnumber = getfont(styles["font-family"],styles["font-size"])
			nodelist = mknodes(v,fontnumber)
            nodelist = add_color(nodelist,styles["color"])
			nodelist = do_linebreak(nodelist,styles.width)
            nodelist = draw_border(nodelist,styles)
            nodelist = boxit(nodelist)
            output_at(nodelist, styles.curx,styles.cury)

		end
	end
	table.remove(stylesstack)
end

handle_element(body)

-- last page
-- draw debugging rule
-- printtable("body",body)
function shipout()
    thispage:addbox()
    tex.box[666] = thispage.pagebox
    tex.shipout(666)
end

shipout()



