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
local fontfamilies = csshtmltree.fontfamilies
local body = csshtmltree[1]


function mknodes( text )
	local head,last
	for s in string.utfvalues(text) do
        n = node.new("glyph")
        n.font = 1
        n.char = s
        head,last = node.insert_after(head,last,n)
	end
	return head
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

local ok,f = fonts.define_font("texgyreheros-regular.otf",12 * 65536)
if ok then
    local num = font.define(f)
    print("ok", num)
else
    print(f)
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


local stylesstackmetatable = {
    __newindex = function( tbl, idx, value )
        rawset(tbl, idx, value)
        value.pos = #tbl
    end
}
local stylesstack = setmetatable({},stylesstackmetatable)
local levelmt = {
    __index = function( tbl,idx )
        if tbl.pos == 1 then return nil end
        return stylesstack[tbl.pos - 1][idx]
    end
}
local styles = setmetatable({},levelmt)

tex.pagewidth = thispage.width
tex.pageheight = thispage.height


styles.width =  thispage.width - thispage.margin_left - thispage.margin_right
styles.height =  thispage.height - thispage.margin_top - thispage.margin_bottom
styles.curx = thispage.margin_left
styles.cury = thispage.margin_top

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
			nodelist = mknodes(v)
			nodelist = do_linebreak(nodelist,styles.width)
            output_at(boxit(nodelist), styles.curx,styles.cury)

		end
	end
	table.remove(stylesstack)
end

handle_element(body)


thispage:addbox()
tex.box[666] = thispage.pagebox

tex.shipout(666)



