-- initialize local file list and other necessary stuff


luasrcdir = os.getenv("SPBASEDIR") .. "/src/lua"
texsrcdir = os.getenv("SPBASEDIR") .. "/src/tex"
fontsdir = os.getenv("SPBASEDIR") .. "/src/fonts"

local function searcher(filename)
    local f = kpse.filelist[filename..".lua"]
    -- w("loader found %q",tostring(f))
    local loader,err = loadfile(f)
    if not loader then
      return "Loading error: "..err
    end
    return loader
end

package.searchers = { searcher }


texconfig.kpse_init=false
texconfig.max_print_line=99999
texconfig.formatname="dummy"


kpse = {}
kpse.filelist = {}


function dirtree(dir)
  assert(dir and dir ~= "", "directory parameter is missing or empty")
  if string.sub(dir, -1) == "/" then
    dir=string.sub(dir, 1, -2)
  end

  local function yieldtree(dir)
    local dirs = {}
    for entry in lfs.dir(dir) do
      if not entry:match("^%.") then
        entry=dir.."/"..entry
        local attr=lfs.attributes(entry)
        if attr then
     	  if attr.mode ~= "directory" then
     	    coroutine.yield(entry,attr)
     	  end
     	  if attr.mode == "directory" then
            table.insert(dirs, entry)
     	  end
        end
      end
    end
    for i = 1, #dirs do
      yieldtree(dirs[i])
    end
  end

  return coroutine.wrap(function() yieldtree(dir) end)
end

local currentdir = lfs.currentdir()
function kpse.add_dir( dir )
	for i in dirtree(dir) do
    	local filename = i:gsub(".*/([^/]+)$","%1")
        -- ignore
        if kpse.filelist[filename] == nil then
            kpse.filelist[filename] = i
        end
    end
end

kpse.add_dir(texsrcdir)
kpse.add_dir(luasrcdir)
kpse.add_dir(fontsdir)

function kpse.find_file(filename,what)
  if not filename then return nil end
  return kpse.filelist[filename] or kpse.filelist[filename .. ".tex"]
end

function do_luafile(filename)
  local a = kpse.find_file(filename)
  assert(a,string.format("Can't find file %q",filename))
  return dofile(a)
end


do_luafile("debug.lua")
do_luafile("callbacks.lua")
