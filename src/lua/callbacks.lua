-- Register callbacks for file i/o (kpathsearch is disabled)

local htmlbase = os.getenv("SPHTMLBASE")

local function reader( filename )
	local tab = { }
	tab.file = io.open(filename,"rb")
	tab.reader = function (t)
                  local f = t.file
                  return f:read('*l')
               end
	tab.close = function (t)
                  t.file:close()
              end
  return tab
end

local function find_read_file( id_number,filename )
	-- w("find_read_file %q",filename)
	local f = kpse.filelist[filename]
	return f
end

local function find_xxx_file( filename )
	-- w("find_xxx_file %q",tostring(filename))
	if filename == "pdftex.map" then return nil end
	local f = htmlbase .. "/" .. filename
	return f
end

local function read_xxx_file(filename)
	-- w("read XXX file %q",tostring(filename))
	local f = io.open(filename,"rb")
	local buf = f:read("*all")
	f:close()
	return true,buf,buf:len()
end

local function return_asked_name( name )
	-- w("return_asked_name %q",tostring(name))
	return name
end

local function read_font_file( filename )
	local f = io.open(filename,"rb")
	local buf = f:read("*all")
	f:close()
	return true,buf,buf:len()
end


function find_write_file(id_number,filename)
	return filename
end



for _,t in ipairs({"find_font_file",'find_vf_file','find_format_file','find_map_file','find_enc_file','find_sfd_file','find_pk_file','find_data_file','find_image_file','find_truetype_file'}) do
	callback.register(t,find_xxx_file)
end
for _,t in ipairs({'read_vf_file','read_sdf_file','read_pk_file','read_data_file','read_font_file','read_map_file'}) do
	callback.register(t, read_xxx_file )
end


callback.register('open_read_file',reader)

callback.register('find_opentype_file',return_asked_name)
callback.register('find_type1_file',   return_asked_name)
callback.register('find_output_file',  return_asked_name)

callback.register('read_opentype_file',read_font_file)
callback.register('read_type1_file',   read_font_file)

callback.register('find_write_file',find_write_file)

callback.register('find_read_file',find_read_file)

