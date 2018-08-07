tex.draftmode=0
tex.enableprimitives('',tex.extraprimitives ())

-- A very large length
maxdimen = 1073741823

tex.hfuzz    = maxdimen
tex.vfuzz    = maxdimen
tex.hbadness = maxdimen
tex.vbadness = maxdimen

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



local fontfamilies = { ["sans-serif"] = {
    regular = {filename =  "texgyreheros-regular.otf" },
    bold   = {filename =  "texgyreheros-bold.otf" },
    italic = {filename =  "texgyreheros-italic.otf" },
  }
}

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
        if string.match(number_or_string, "em$") then
            local amount = string.gsub(number_or_string, "^(.*)r?em$","%1")
            return tonumber(amount) * tex.sp("12pt")
        end
        number_or_string = string.gsub(number_or_string,"(%d)pt","%1bp"):gsub("(%d)pp","%1pt")
        local ret = { pcall(orig_texsp,number_or_string) }
        if ret[1]==false then
            w("Could not convert dimension %q",number_or_string)
            return nil
        end
        return unpack(ret,2)
    end
    return orig_texsp(number_or_string)
end


local body = csshtmltree[1]

fonttable = {}

function mknodes( text, styles )
    local fontnum = getfont(styles)
    local tbl      = fonttable[fontnum]

    local space    = tbl.parameters.space
    local shrink   = tbl.parameters.space_shrink
    local stretch  = tbl.parameters.space_stretch

    local match = unicode.utf8.match
	local head,last
	for s in string.utfvalues(text) do
        local char = unicode.utf8.char(s)
        if match(char,"^%s$") then -- Space
            n = node.new(glue_node)
            n.width = space
            n.shrink = shrink
            n.stretch = stretch
        else
            n = node.new("glyph")
            n.font = fontnum
            n.char = s
        end
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


function getfont(styles)
    local family, size, weight, style =  styles["font-family"],styles["font-size"], styles["font-weight"],styles["font-style"]

    if not size then
        print("Size not given")
        size = tex.sp("12pt")
    else
        size = tex.sp(size)
    end
    local fontselector = "regular"
    if weight == "bold" then
        if style == "normal" then
            fontselector = "bold"
        elseif style == "italic" then
            fontselector = "bolditalic"
        end
    elseif weight == "normal" then
        if style == "italic" then
            fontselector = "italic"
        end
    end

    local fam = fontfamilies[fontfamily or "sans-serif"]
    if fam[fontselector] and fam[fontselector].fontnumber then
        return fam[fontselector].fontnumber
    end

    -- printtable("fam",fam[fontselector])
    local ok, f = fonts.define_font(fam[fontselector].filename,tex.sp(size))
    if ok then
        local num = font.define(f)
        fam[fontselector].fontnumber = num
        fonttable[num] = f
    else
        print(f)
    end
    return fam[fontselector].fontnumber
end

function do_linebreak( nodelist,hsize )
    assert(nodelist,"No nodelist found for line breaking.")
    finish_par(nodelist)
    parameters = parameters or {}

    local pdfignoreddimen = -65536000
    tex.baselineskip = tex.sp("12pt")
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
    node.set_attribute(gluebordertop,    010,1)
    node.set_attribute(glueborderright,  010,2)
    node.set_attribute(glueborderbottom, 010,3)
    node.set_attribute(glueborderleft,   010,4)

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
        y4 = y3 + sp_to_bp(rule_width_top)
        rules[#rules + 1] = string.format("%s 0 w %g %g m %g %g l %g %g l %g %g l h f", colorstring,  x1,y1,x2,y2, x3,y3, x4,y4)
    end
    rules[#rules + 1] = "Q"

    nodelist = node.insert_before(nodelist,nodelist,glueborderleft)
    nodelist = node.insert_after(nodelist,node.tail(nodelist),glueborderright)
    local box = node.hpack(nodelist)
    box = node.insert_before(box,box,gluebordertop)
    box = node.insert_after(box,node.tail(box),glueborderbottom)
    if #rules > 2 then
        local wbox = node.new("whatsit","pdf_literal")
        wbox.data = table.concat(rules, " ")
        wbox.mode = 0

        box = node.insert_after(box,node.tail(box),wbox)
    end
    box = node.vpack(box)

    return box
end

function isspace( str )
    if string.match(str,"^%s*$") then return true else return false end
end

function remove_space_beginning( str )
    return string.gsub(str, "^%s*", "")
end

function remove_space_end( str )
    return string.gsub(str, "%s*$", "")
end


local stylesstackmetatable = {
    __newindex = function( tbl, idx, value )
        rawset(tbl, idx, value)
        value.pos = #tbl
    end
}

inherited = {
    width = false, calculated_width = true,
    ["border-collapse"] = true, ["border-spacing"] = true, ["caption-side"] = true, ["color"] = true, ["direction"] = true, ["empty-cells"] = true, ["font-family"] = true, ["font-size"] = true, ["font-style"] = true, ["font-variant"] = true, ["font-weight"] = true, ["font"] = true, ["letter-spacing"] = true, ["line-height"] = true, ["list-style-image"] = true, ["list-style-position"] = true, ["list-style-type"] = true, ["list-style"] = true, ["orphans"] = true, ["quotes"] = true, ["richness"] = true, ["text-align"] = true, ["text-indent"] = true, ["text-transform"] = true, ["visibility"] = true, ["white-space"] = true, ["widows"] = true, ["word-spacing"] = true
}

local stylesstack = setmetatable({},stylesstackmetatable)
local levelmt = {
    __index = function( tbl,idx )
        if tbl.pos == 1 then return nil end
        if inherited[idx] then
            -- w("idx %q",tostring(idx))
            return stylesstack[tbl.pos - 1][idx]
        else
            return nil
        end
    end
}
local styles = setmetatable({},levelmt)
styles.color = "black"
styles["font-family"] = "sans-serif"
styles["font-size"] = "12pt"
styles["font-weight"] = "normal"
styles["font-style"] = "normal"


stylesstack[#stylesstack + 1] = styles

local MVERTICAL, MHORIZONTAL = 1,2

local mode = {MVERTICAL}



function do_inline_block( elt )
    local ret = nil
    local styles = setmetatable({},levelmt)

	stylesstack[#stylesstack + 1] = styles
	if elt.attributes then
		for i,v in pairs(elt.attributes) do
			styles[i] = v
		end
	end

    if #elt == 0 then
        ret = mknodes("X")
    end
    local doremove = {}
    local child
    for i=1,#elt do
        child = elt[i]
        if type(child) == "table" then
            local childname = child.elementname
            if childname == "p" or childname == "img" or childname == "b" or childname == "li"  then
                mode[#mode + 1] = MHORIZONTAL
            else
                mode[#mode + 1] = MVERTICAL
            end
            local nodes = do_inline_block(child)
            table.remove(mode)
            local tail = node.tail(ret)
            if tail then
                tail.next = nodes
                nodes.prev = tail
            else
                ret = nodes
            end
        elseif type(child) == "string" then
            if mode[#mode] == MHORIZONTAL and mode[#mode - 1] == MVERTICAL then
                if i == 1 then
                    child = remove_space_beginning(child)
                elseif i == #elt then
                    child = remove_space_end(child)
                end
            end
            -- in vertical mode, empty strings don't start a horizontal list
            if not(mode[#mode] == MVERTICAL and isspace(child)) then
                local nodes = mknodes(child,styles)
                local tail = node.tail(ret)
                if tail then
                    tail.next = nodes
                    nodes.prev = tail
                else
                    ret = nodes
                end
            else
                -- we need to remove the empty spaces
                doremove[#doremove + 1] = i
            end
        else
            w("type %q not handled",type(child))
        end
    end

    for i=#doremove,1,-1 do
        table.remove(elt,doremove[i])
    end
    local parentmode = mode[#mode - 1]

    if parentmode == MVERTICAL then
        if mode[#mode] == MHORIZONTAL then
            for i=1,#elt do
                elt[i] = nil
            end
        end
        elt.nodelist = ret
        ret = nil
    end

    table.remove(stylesstack)
    return ret
end

function set_calculated_width( styles )
    local sw = styles.width or "100%"
    -- w("styles.width %q",tostring(styles.width))
    if string.match(sw,"%d+%%$") then
        -- xx percent
        local amount = string.match(sw,"(%d+)%%$")
        styles.calculated_width = math.round(styles.calculated_width * tonumber(amount) / 100 ,0)
    elseif tex.sp(sw) then
        -- a length
        styles.calculated_width = tex.sp(sw)
    end
end

-- two adjacent box elements collapse their margin
-- https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_Box_Model/Mastering_margin_collapsing
function fixup_things( elt )
    for i=1,#elt - 1 do
        curelement = elt[i]
        nextelt = elt[i + 1]
        if nextelt then
            local inbetween = math.round(math.max(tex.sp(curelement.attributes["margin-bottom"]),tex.sp(nextelt.attributes["margin-top"])) / 2)
            curelement.attributes["margin-bottom"] = inbetween
            nextelt.attributes["margin-top"] = inbetween
        end
    end
end

local thispage
local mvl = node.new("vlist")

function add_to_mvl( vlist )
    mvl.list = node.insert_after(mvl.list, node.tail(mvl.list),vlist)
end

function output_p( elt,wd )
    local vlist = do_linebreak(elt.nodelist,wd)
    vlist = draw_border(vlist,elt.attributes)
    add_to_mvl(vlist)
end

function do_output( elt )
    local styles = setmetatable({},levelmt)
    stylesstack[#stylesstack + 1] = styles
    if thispage == nil then
        thispage = page:new(csshtmltree.pages["*"])
        tex.pagewidth = thispage.width
        tex.pageheight = thispage.height
        styles.calculated_width = thispage.width - thispage.margin_left - thispage.margin_right
    end

    if elt.attributes then
        for i,v in pairs(elt.attributes) do
            styles[i] = v
        end
    end
    calculated_width = set_calculated_width(styles)

    local curelement
    for i=1,#elt do
        curelement = elt[i]
        if type(curelement) == "table" then
            if curelement.elementname == "p" then
                output_p(curelement,styles.calculated_width)
            end
        end
    end
    table.remove(stylesstack)
end

do_inline_block(body)
fixup_things(body)
do_output(body)


if thispage then
    local objects = {}

    objects[1] = mvl.head
    objects[2] = mvl.head.next
    objects[1].next = nil
    objects[2].prev = nil


    local left = set_glue(nil,{width = thispage.margin_left})
    local top  = set_glue(nil,{width = thispage.margin_top})

    node.set_attribute(left,11,1)
    node.set_attribute(top,11,2)
    vlist = node.insert_after(objects[1],objects[1],objects[2])
    vlist = node.vpack(vlist)

    left = node.insert_after(left,left,vlist)
    left = node.hpack(left)
    top = node.insert_after(top,top,left)

    top = node.vpack(top)



    tex.box[666] = top
    tex.shipout(666)
end
