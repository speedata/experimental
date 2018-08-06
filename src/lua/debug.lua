
function w( ... )
  local ok,fmt = pcall(string.format,...)
  if ok == false then
    print("-(e)-> " .. fmt)
    print(debug.traceback())
  else
    print("-----> " .. fmt)
  end
  io.stdout:flush()
end

if not log then
  log = function (...)
    print(string.format(...))
  end
end


do
  tables_printed = {}
  function printtable (ind,tbl_to_print,level)
    if type(tbl_to_print) ~= "table" then
      log("printtable: %q ist keine Tabelle, es ist ein %s (%q)",tostring(ind),type(tbl_to_print),tostring(tbl_to_print))
      return
    end
    level = level or 0
    local k,l
    local key
    if level > 0 then
      if type(ind) == "number" then
        key = string.format("[%d]",ind)
      else
        key = string.format("[%q]",ind)
      end
    else
      key = ind
    end
    log(string.rep("  ",level) .. tostring(key) .. " = {")
    level=level+1

    for k,l in pairs(tbl_to_print) do
        if type(l) == "userdata" and node.is_node(l) then
            l = "♢" .. nodelist_tostring(l)
        end
      if (type(l)=="table") then
        if k ~= ".__parent" then
          printtable(k,l,level)
        else
          log("%s[\".__parent\"] = <%s>", string.rep("  ",level),l[".__name"])
        end
      else
        if type(k) == "number" then
          key = string.format("[%d]",k)
        else
          key = string.format("[%q]",k)
        end
        log("%s%s = %q", string.rep("  ",level), key,tostring(l))
      end
    end
    log(string.rep("  ",level-1) .. "},")
  end
end



function nodelist_tostring( head )
    local ret = {}
    while head do
        if head.id == hlist_node or head.id == vlist_node then
            ret[#ret + 1] = nodelist_tostring(head.head)
        elseif head.id == glyph_node then
            ret[#ret + 1] = unicode.utf8.char(head.char)
        elseif head.id == rule_node then
            if  head.width > 0 then
                ret[#ret + 1] = "|"
            end
        elseif head.id == penalty_node then
            if head.next and head.next.id == glue_node and head.next.next and head.next.next.id == penalty_node then
                ret[#ret + 1] = "↩"
                head = head.next
                head = head.next
            end
        elseif head.id == glue_node then
            ret[#ret + 1] = "·"
        elseif head.id == whatsit_node then
            if head.subtype == pdf_refximage_whatsit then
                ret[#ret + 1] = string.format("⊡")
            else
                ret[#ret + 1] = "¿"
            end
        else
            w(head.id)
        end

        head = head.next
    end
    return table.concat(ret,"")
end
