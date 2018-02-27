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
        s.margin_left = tex.sp(csspage["margin-left"])
        s.margin_top = tex.sp(csspage["margin-top"])
        s.margin_right = tex.sp(csspage["margin-right"])
        s.margin_bottom = tex.sp(csspage["margin-bottom"])
    end
  setmetatable(s, self)
  return s
end

function addbox(self)
    local rule_width = 0.3
    local wbox = node.new("whatsit","pdf_literal")
    local wd = self.width - self.margin_right - self.margin_left
    local ht =  self.height - self.margin_top - self.margin_bottom
    wd = wd / factor - rule_width
    ht = ht / factor - rule_width

    wbox.data = string.format("q 0 G %g w %g %g %g %g re s Q",rule_width ,self.margin_left / factor, -self.margin_top / factor, wd, -ht)
    wbox.mode = 0
    -- Draw box at the end so its contents gets "below" it.
    self.pagebox.head = node.insert_before(self.pagebox.head,self.pagebox.head,wbox)
end

-- return page

-- local page_margin_top, page_margin_right,page_margin_bottom, page_margin_left = page["margin-top"],page["margin-right"],page["margin-bottom"],page["margin-left"]
