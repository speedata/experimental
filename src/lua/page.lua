--
--  page.lua

-- local page = {}


module(...,package.seeall)
_M.__index = _M

function page.new( self,csspage)
    assert(self)
    local s = {}
    if not csspage then
        s.width = tex.sp("210mm")
        s.height = tex.sp("297mm")
        s.margin_left = tex.sp("1cm")
        s.margin_top = tex.sp("1cm")
        s.margin_right = tex.sp("1cm")
        s.margin_bottom = tex.sp("1cm")
    else
        s.width = tex.sp(csspage.width)
        s.height = tex.sp(csspage.height)
        s.margin_left = tex.sp(csspage["margin-left"] or "1cm")
        s.margin_top = tex.sp(csspage["margin-top"] or "1cm")
        s.margin_right = tex.sp(csspage["margin-right"] or "1cm")
        s.margin_bottom = tex.sp(csspage["margin-bottom"] or "1cm")
    end

    s.pagegoal = s.height - s.margin_top - s.margin_bottom
    s.csspage = csspage
    setmetatable(s, self)
    return s
end

function page.finish(self,box)
    box.width = self.width - self.margin_left - self.margin_right
    box.height = self.height - self.margin_top - self.margin_bottom
    box = draw_border(box,self.csspage)
    tex.box[666] = box
    tex.shipout(666)
end