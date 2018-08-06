--
--  page.lua

-- local page = {}


module(...,package.seeall)
_M.__index = _M

function page.new( self,csspage)
    assert(self)
    local s = {
        pagebox = node.new("vlist"),
    }

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
  setmetatable(s, self)
  return s
end
