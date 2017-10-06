-- NG-85826; NG-91245
local logger = require("transformer.logger")
local log = logger.new("ConfigCommon")

local type, pairs, ipairs, next = type, pairs, ipairs, next
local format, match, gsub = string.format, string.match, string.gsub

local uci = require("uci")
local uci_cursor

local export_version = "1.00"
local export_list = "/etc/config.export"
local export_location = "/tmp/"

local import_list = "/etc/config.import"
local import_location = "/tmp/"

local uci_path_header = {
  BOARDMNEMONIC = "env.rip.board_mnemonic",
  PRODUCTNAME = "env.var.prod_name",
  SERIALNUMBER = "env.var.serial",
  MAC = "env.rip.eth_mac",
  BUILDVERSION = "env.var.friendly_sw_version_activebank",
}

local M = {}

local function throw_error()
  error({ info = debug.getinfo(2, 'nl')})
end

local function get_error_info(err)
  if type(err) == 'string' then return err end
  if type(err) ~= 'table' or type(err.info) ~= 'table' then return nil end
  return format("line=%d, name=%s", err.info.currentline, err.info.name or "?")
end

local function export_set_error(export_mapdata, info)
  export_mapdata.state = "Error"
  export_mapdata.info = info or ""
  log:error("Error: " .. info or "?")
end

local crypto = require("lcrypto")

local cipher_scheme = "AES-256-CBC"
local signature_scheme = "HMAC-SHA1"

local rip_path = "/proc/rip/"
local rip_random_B = "0108"
local rip_random_D = "012b"

local uci_prefix_config = "system.config."

local function uci_get_boolean(path)
  local boolean_true = { ["true"] = true, ["1"] = true, ["yes"] = true, ["on"] = true }
  return (boolean_true[uci_cursor:get(path)] or false)
end

-- return true if export in plaintext (no encryption)
local function check_export_plaintext()
  return uci_get_boolean(uci_prefix_config .. "export_plaintext")
end

-- return true if import in plaintext is allowed
local function check_import_plaintext()
  return uci_get_boolean(uci_prefix_config .."import_plaintext")
end

-- return true if export should be unsigned
local function check_export_unsigned()
  return uci_get_boolean(uci_prefix_config .. "export_unsigned")
end

-- return true if import without signature is allowed
local function check_import_unsigned()
  return uci_get_boolean(uci_prefix_config .. "import_unsigned")
end

local function get_rip_random(rip_random)
  local f_rip_random = io.open(rip_path .. rip_random, "rb")
  if not f_rip_random then return end

  local random_key = f_rip_random:read("*all")
  f_rip_random:close()
  return random_key
end
--get the common key
local function get_export_commonkey()
  local expcommonkey = uci_cursor:get(uci_prefix_config .. "export_commonkey")
  if expcommonkey == nil then
    expcommonkey = "GW"
  end
  return expcommonkey
end

local function get_import_commonkey()
  local impcommonkey = uci_cursor:get(uci_prefix_config .. "import_commonkey")
  if impcommonkey == nil then
    impcommonkey = "GW"
  end
  return impcommonkey
end

local function get_cipher_key(common_key)
  local random_key
  if common_key == "GW" then
    random_key = get_rip_random(rip_random_B)
  elseif common_key == "GW_KEYD" then
    random_key = get_rip_random(rip_random_D)
  else
    throw_error()
  end
  if not random_key or #random_key < 32 then throw_error() end
  return random_key:sub(1,32)
end

local function get_signature_key(common_key)
  local random_key
  if common_key == "GW" then
    random_key = get_rip_random(rip_random_B)
    if not random_key or #random_key < 64 then throw_error() end
    return random_key:sub(1,64)
  elseif common_key == "GW_KEYD" then
    random_key = get_rip_random(rip_random_D)
    if not random_key or #random_key < 64 then throw_error() end
    return random_key:sub(33,96)
  else
    throw_error()
  end
end

-- parse "package.section/@section[i].param"
local function parse_object_path(path)
  local package, section, index, param

  -- package
  package, section = path:match("^([^%.]+)(.*)")
  if not package then throw_error() end
  if #section == 0 then
    return package
  end

  -- section, index
  section, param = section:sub(2):match("^([^%.]+)(.*)")
  if not section then throw_error() end
  -- check for anonymous section
  if section:sub(1,1) == "@" then
    section, index = section:sub(2):match("^([^%[]+)(.*)")
    if not section then throw_error() end
    if #index == 0 then
      index = true
    else
      index = index:match("%[(%d+)%]$")
      if not index then throw_error() end
    end
  end
  if #param == 0 then
    return package, section, index
  end

  -- param
  param = param:sub(2)
  if not param then throw_error() end
  return package, section, index, param
end

local function parse_object_value(value)
  -- check if value is single string (option) or multiple (list)
  local simple_value = value:match("^'(.*)'$")
  if simple_value then
    return simple_value
  end

  local list_value = value:match("^{(.*)}$")
  if list_value then
    local list_elems = {}
    for elem in list_value:gmatch("'(.-)'") do
      list_elems[#list_elems + 1] = elem
    end
    return list_elems
  end

  throw_error()
end

local function config_read_list(list, file)
  list.pkg = {}

  for line in file:lines() do
    -- drop comments
    line = line:match("^[^#]*")
    -- keep first word only
    line = line:match("^%S+")
    if line then  -- skip empty lines
      local value, package, section
      if line:sub(1,1) == "^" then
        value = false
        line = line:sub(2)
      else
        value = true
      end

      local package, section, index, param = parse_object_path(line)
      if index then section = "@" .. section end -- prevent name clashes

      if not list.pkg[package] then list.pkg[package] = { sn = {} } end
      if not section then
        list.pkg[package].value = value
      else
        if not list.pkg[package].sn[section] then list.pkg[package].sn[section] = { pm = {} } end
        if not param then
          list.pkg[package].sn[section].value = value
        else
          if not list.pkg[package].sn[section].pm[param] then list.pkg[package].sn[section].pm[param] = {} end
          list.pkg[package].sn[section].pm[param].value = value
        end
      end
    end
  end

  list.all = (list.pkg["*"] and list.pkg["*"].value) or false
end

-- Export

local function export_compose_header(export_data)
  local header = {}
  local function add_header_uci(key)
    local value, err = uci_cursor:get(uci_path_header[key])
    if not value then throw_error() end
    header[#header+1] = { key = key, value = value }
  end

  header[#header+1] = { key = "PREAMBLE", value = "THENC" }
  header[#header+1] = { key = "BACKUPVERSION", value = export_version }
  add_header_uci("BOARDMNEMONIC")
  add_header_uci("PRODUCTNAME")
  add_header_uci("SERIALNUMBER")
  add_header_uci("MAC")
  add_header_uci("BUILDVERSION")
  if not check_export_plaintext() then
    header[#header+1] = { key = "CIPHERKEY", value = get_export_commonkey() }
  end
  if not check_export_unsigned() then
    header[#header+1] = { key = "SIGNATUREKEY", value = get_export_commonkey() }
  end

  export_data.header = header

  -- copy into rawheader
  header = {}
  for _,entry in ipairs(export_data.header) do
    header[#header+1] = entry.key .. "=" .. entry.value
  end
  export_data.rawheader = table.concat(header, "\n") .. "\n\n"
end

local function export_config_add(data, line)
  data[#data+1] = line
end

local function export_config_start_package(data, package)
  export_config_add(data, format("[%s]", package))
end

local function export_config_end_package(data, package)
  export_config_add(data, "")
end

local function export_config_start_section(data, package, section)
  export_config_add(data, format("[%s.%s]", package, section))
end

local function export_config_end_section(data, package, section)
  export_config_add(data, "")
end

local function export_config_set_section(data, package, section, sectiontype)
  export_config_add(data, format("%s.%s=%s", package, section, sectiontype))
end

local function export_config_set_param(data, package, section, key, value)
  if type(value) == "string" then
    value = gsub(value, "'", "\\'")
    export_config_add(data, format("%s.%s.%s='%s'", package, section, key, value))
    return
  end
  if type(value) == "table" then
    for i,elem in ipairs(value) do
      value[i] = "'" .. gsub(elem, "'", "\\'") .. "'"
    end
    export_config_add(data, format("%s.%s.%s={%s}", package, section, key, table.concat(value, ',')))
    return
  end
end

local function export_section(data, package, section, sn)
  export_config_start_section(data, package, section)

  if section:sub(1,1) == "@" then
    local sectiontype = section:sub(2)
    -- iterate type instances
    uci_cursor:foreach(package, sectiontype, function(uci_section)
      local instancename = format("%s[%d]", section, uci_section['.index'])
      export_config_set_section(data, package, instancename, sectiontype)

      for key,value in pairs(uci_section) do
        if not match(key, "^[._]") and ((not sn.pm[key] and sn.value) or (sn.pm[key] and sn.pm[key].value)) then
          export_config_set_param(data, package, instancename, key, value)
        end
      end
      -- required to keep iterating
      return true
    end)
  else
    local uci_section = uci_cursor:get_all(package, section)
    if uci_section then
      export_config_set_section(data, package, section, uci_section['.type'])

      for key,value in pairs(uci_section) do
        if not match(key, "^[._]") and ((not sn.pm[key] and sn.value) or (sn.pm[key] and sn.pm[key].value)) then
          export_config_set_param(data, package, section, key, value)
        end
      end
    end
  end

  export_config_end_section(data, package, section)
end

local function export_package(data, package, pkg)
  if pkg.value then --export undefined sections fully
    export_config_start_package(data, package)
    local types_count = {}
    -- iterate all sections
    uci_cursor:foreach(package, function(uci_section)
      local sectiontype = uci_section['.type']
      local sectionname
      if uci_section['.anonymous'] == false then
        sectionname = uci_section['.name']
        if (pkg.sn[sectionname] ~= nil) then return true end -- skip (defined section)
      else
        if pkg.sn["@" .. sectiontype] ~= nil then return true end  -- skip (defined sectiontype)
        types_count[sectiontype] = (types_count[sectiontype] and types_count[sectiontype] + 1) or 0
        sectionname = format('@%s[%d]', sectiontype, types_count[sectiontype])
      end
      export_config_set_section(data, package, sectionname, sectiontype)

      for key,value in pairs(uci_section) do
        if not match(key, "^[._]") then
          export_config_set_param(data, package, sectionname, key, value)
        end
      end
      -- required to keep iterating
      return true
    end)

    export_config_end_package(data, package)
  end

  -- export other sections as defined
  for section,sn in pairs(pkg.sn) do
    export_section(data, package, section, sn)
  end
end

local function export_collect_configdata(export_data, list)
  local data = {}
  local packages = uci_cursor:list_configs()
  if not packages then throw_error() end

  if list.all then
     -- add identifier
    export_config_add(data, "[*]")
    export_config_add(data, "")
  end

  for _,package in ipairs(packages) do
    if list.pkg[package] or list.all then
      -- check if the config file truly has data; ignore if not
      local all = uci_cursor:get_all(package)
      if next(all) then
        export_package(data, package, list.pkg[package] or { value = true, sn = {} })
      end
    end
  end

  export_data.plaintext = table.concat(data, "\n")
end

local function export_encrypt_data(export_data)
  export_data.iv = crypto.random(16)
  if not export_data.iv then throw_error() end

  export_data.ciphertext = crypto.encrypt(cipher_scheme, get_cipher_key(get_export_commonkey()), export_data.iv, export_data.plaintext)
  if not export_data.ciphertext then throw_error() end

  -- remove plaintext from export_data
  export_data.plaintext = nil
end

local function export_add_signature(export_data)
  local data = { export_data.rawheader }
  if export_data.plaintext then
    table.insert(data, export_data.plaintext)
  else
    table.insert(data, export_data.iv)
    table.insert(data, export_data.ciphertext)
  end
  export_data.signature = crypto.sign(signature_scheme, get_signature_key(get_export_commonkey()), table.concat(data))
  if not export_data.signature then throw_error() end
end

local function export_write_data(export_data, filepath)
  os.remove(filepath)
  -- create empty export file
  local f_data = io.open(filepath, "w")
  if not f_data then throw_error() end
  -- write header
  if not f_data:write(export_data.rawheader) then throw_error() end

  if export_data.plaintext then
    -- write config as plaintext
    if not f_data:write(export_data.plaintext) then throw_error() end
  else
    -- write iv and encrypted data
    if not f_data:write(export_data.iv, export_data.ciphertext) then throw_error() end
  end
  if export_data.signature then
    -- write signature
    if not f_data:write(export_data.signature) then throw_error() end
  end
  f_data:close()
end

local function export_execute(export_mapdata)
  export_mapdata.info = "export started"

  local rv, err
  local export_data = {}

  -- open file with export rules
  export_mapdata.info = "composing header info"
  rv, err = pcall(export_compose_header, export_data)
  if not rv then
    export_set_error(export_mapdata, format("compose header failed (%s)", get_error_info(err) or "?"))
    return
  end

  export_mapdata.info = "reading export list"
  -- open file with export rules
  local f_list = io.open(export_list, "r")
  if not f_list then
    export_set_error(export_mapdata, "open export list failed")
    return
  end
  -- read export rules
  local export_config_list = {}
  rv, err = pcall(config_read_list, export_config_list, f_list)
  if not rv then
    export_set_error(export_mapdata, format("read export list failed (%s)", get_error_info(err) or "?"))
    export_config_list = nil
  end
  -- cleanup
  f_list:close()
  -- check if read failed
  if not export_config_list then return end

  -- collect export data
  export_mapdata.info = "collecting export data"
  rv, err = pcall(export_collect_configdata, export_data, export_config_list)
  if not rv then
    export_set_error(export_mapdata, format("collect export data failed (%s)", get_error_info(err) or "?"))
    return
  end

  -- encrypt export data if not disabled
  if not check_export_plaintext() then
    export_mapdata.info = "encrypting export data"
    rv, err = pcall(export_encrypt_data, export_data)
    if not rv then
      export_set_error(export_mapdata, format("encrypt export data failed (%s)", get_error_info(err) or "?"))
      return
    end
  end

  -- sign export data if not disabled
  if not check_export_unsigned() then
    export_mapdata.info = "signing export data"
    rv, err = pcall(export_add_signature, export_data)
    if not rv then
      export_set_error(export_mapdata, format("sign export data failed (%s)", get_error_info(err) or "?"))
      return
    end
  end

  -- write export data to file
  export_mapdata.info = "writing export data"
  rv, err = pcall(export_write_data, export_data, export_mapdata.location .. export_mapdata.filename)
  if not rv then
    export_set_error(export_mapdata, format("write export data failed (%s)", get_error_info(err) or "?"))
    return
  end

  export_mapdata.state = "Complete"
  export_mapdata.info = "export succesfully completed"
end

function M.export_reset(export_mapdata)
  export_mapdata.state = "None"
  export_mapdata.info = ""
end

function M.export_init(location)
  local export_mapdata = {}
  M.export_reset(export_mapdata)
  export_mapdata.version = export_version
  if location then
    export_mapdata.location = location
  else
    export_mapdata.location = export_location
  end
  return export_mapdata
end

function M.export_start(export_mapdata, path)
  if not export_mapdata.filename or export_mapdata.filename == "" then
    export_set_error(export_mapdata, "invalid filename")
    return
  end

  uci_cursor = uci.cursor(path)
  export_execute(export_mapdata)
  uci_cursor:close()
  uci_cursor = nil
end

-- Import

local function import_set_error(import_mapdata, info)
  import_mapdata.state = "Error"
  import_mapdata.info = info or ""
  log:error("Error: " .. info or "?")
end

local function config_create_package(package)
  if not uci_cursor:create_config_file(package) then throw_error() end
end

local function config_reset_package(package)
   local sections = {}
   -- iterate all sections
  uci_cursor:foreach(package, function(section)
    sections[#sections + 1] = section['.name']
    -- required to keep iterating
    return true
  end)

  -- delete all sections
  for _,section in ipairs(sections) do
    if not uci_cursor:delete(package, section) then throw_error() end
  end
end

local function config_reset_section(package, section)
  uci_cursor:delete(package, section)
end

local function import_parse_header(line, entry)
  local package, section, index, param

  package, section, index, param = parse_object_path(line)
  if index or param then throw_error() end  -- not yet supported

  entry.package = package
  entry.section = section
  entry.param = param
end

local function import_parse_data_set(line, entry)
  local path, value
  path, value = line:match("^(.-)=(.+)")
  if not path then throw_error() end

  local package, section, index, param
  package, section, index, param = parse_object_path(path)

  if param then
    value = parse_object_value(value)
    if not value then throw_error() end
  end

  entry.package = package
  entry.section = section
  entry.index = index
  entry.param = param
  entry.value = value
end

--- read and verify the file header
-- @param file the file object to read from
-- @return header, rawheader
-- with header a table with the key/value pairs in the header
-- and rawheader a string with the exact content of the header.
local function read_header(file)
  local header = {}
  local raw = {}
  local line = file:read('*l')
  if line~="PREAMBLE=THENC" then
    throw_error()
  end
  raw[1] = line
  while true do
    local line = file:read("*l")
    if line=="" then break end
    local k, v = line:match("^([^=]+)=(.*)$")
    if not k  or header[k] then
      throw_error()
    end
    header[k] = v
    raw[#raw+1] = line
  end
  -- add an explicit newline so that the rawheader will end with two consecutive
  -- newline characters (just as in the file).
  -- This is important as the signature check will fail if the rawheader does
  -- not match the file exactly.
  raw[#raw+1] = "\n"
  return header, table.concat(raw, '\n')
end

local function import_read_data(import_data, filepath)
  -- open import file
  local f_data = io.open(filepath, "rb")
  if not f_data then
    throw_error()
  end

  --  read in the header, throws error if header is incorrect
  import_data.header, import_data.rawheader = read_header(f_data)

  -- read the rest of the file
  import_data.rawcontent = f_data:read("*all")
  f_data:close()
end

-- NG-85826
local function import_check_buildversion(import_data)
	bv_dev = uci_cursor:get(uci_path_header["BUILDVERSION"])
	if bv_dev ~= import_data.header["BUILDVERSION"] then
		if string.match(import_data.header["BUILDVERSION"] , "_DUMMY") then
			if import_data.header["BUILDVERSION"] ~= string.format("%s%s", bv_dev, "_DUMMY") then
				throw_error()
			end
		elseif string.match(bv_dev , "_DUMMY") then
			if bv_dev ~= string.format("%s%s", import_data.header["BUILDVERSION"], "_DUMMY") then
				throw_error()
			end
		else
			throw_error()
		end
	end
end

local function import_check_signature(import_data)
  if import_data.header["SIGNATUREKEY"] ~= get_import_commonkey()
     or #import_data.rawcontent < 20 then
    throw_error()
  end

  import_data.signature = import_data.rawcontent:sub(-20, -1)
  import_data.rawcontent = import_data.rawcontent:sub(1, -21)

  if true ~= crypto.validate(signature_scheme, get_signature_key(get_import_commonkey()), import_data.rawheader .. import_data.rawcontent,
                             import_data.signature) then
    throw_error()
  end
end

local function import_decrypt_data(import_data)
  if import_data.header["CIPHERKEY"] ~= get_import_commonkey()
     or #import_data.rawcontent < 16 then
    throw_error()
  end

  local iv = import_data.rawcontent:sub(1,16)
  import_data.rawcontent = import_data.rawcontent:sub(17)

  local plaintext = crypto.decrypt(cipher_scheme, get_cipher_key(get_import_commonkey()), iv, import_data.rawcontent)
  if not plaintext then
    throw_error()
  end

  -- replace encrypted rawcontent with plaintext
  import_data.rawcontent = plaintext
end

local function import_parse_content(import_data)
  local data = {}
  for line in string.gmatch(import_data.rawcontent, "([^\n]+)") do
    if line:match("^%S+") then -- skip empty lines
      local data_entry = {}
      local header = line:match("^%[(.*)%]$")
      if header then
        data_entry.type = 'header'
        import_parse_header(header, data_entry)
      else
        data_entry.type = 'set'
        import_parse_data_set(line, data_entry)
      end
      table.insert(data, data_entry)
    end
  end
  -- remove rawcontent from import_data and add config data
  import_data.rawcontent = nil
  import_data.config = data
end

local function import_filter_configdata(data, list)
  local i = 1
  while data[i] do
    local entry = data[i]
    local allowed
    if list.pkg[entry.package] == nil then
      allowed = list.all
    else
      allowed = list.pkg[entry.package].value
    end
    if allowed then
      i = i + 1
    else
      table.remove(data, i)
    end
  end
end

local function import_list_packages()
  local packages = uci_cursor:list_configs()
  if not packages then return {} end

  local list = {}
  for _,package in ipairs(packages) do
    list[package] = { sectionnames = {} }
  end
  return list
end

local function import_create_package(package)
  config_create_package(package)
  return { sectionnames = {} }
end

local function import_apply_header(entry)
  if not entry.section then
    config_reset_package(entry.package)
  else
    config_reset_section(entry.package, entry.section)
  end
end

local function import_apply_set_section(entry, pkg)
  if entry.index then
    local name = uci_cursor:add(entry.package, entry.section)
    if not name then throw_error() end
    if not pkg.sectionnames[entry.section] then
      pkg.sectionnames[entry.section] = {}
    end
    pkg.sectionnames[entry.section][entry.index] = name
  else
    if not uci_cursor:set(entry.package, entry.section, entry.value) then throw_error() end
  end
end

local function import_apply_set_param(entry, pkg)
  local sectionname
  if entry.index then
    sectionname = pkg.sectionnames[entry.section][entry.index]
  end
  local t_value = type(entry.value)
  if t_value == "string" then
    entry.value = gsub(entry.value, "\\'", "'")
  elseif t_value == "table" then
    for i, value in ipairs(entry.value) do
      entry.value[i] = gsub(value, "\\'", "'")
    end
  end
  if not uci_cursor:set(entry.package, sectionname or entry.section, entry.param, entry.value) then throw_error() end
end

local function import_apply_configdata(data)
  local packages = import_list_packages()
  -- special case
  packages["*"] = {}

  if #data == 0 then throw_error() end -- nothing to apply
  for _,entry in ipairs(data) do
    if entry.type == 'header' then
      if entry.package ~= "*" then -- ignore this special case
        -- create package if needed
        if not packages[entry.package] then
          packages[entry.package] = import_create_package(entry.package)
        end
        import_apply_header(entry)
        -- mark package for commit
        packages[entry.package].commit = true
      end
    elseif entry.type == 'set' then
      if not entry.param then
        import_apply_set_section(entry, packages[entry.package])
      else
        import_apply_set_param(entry, packages[entry.package])
      end
    else
      throw_error()
    end
  end

  -- commit marked packages
  for name,package in pairs(packages) do
    if package.commit then
      if not uci_cursor:commit(name) then throw_error() end
    end
  end
end

local function set_vendor_config_param(param, value)
  if param and value then
    if not uci_cursor:set("env", "var", param, value) then
      throw_error()
    end
  end
end

local function import_execute(import_mapdata)
  import_mapdata.info = "import started"

  local rv, err
  local import_data = {}

  import_mapdata.info = "reading import list"
  -- open file with import rules
  local f_list = io.open(import_list, "r")
  if not f_list then
    import_set_error(import_mapdata, "open import list failed")
    return
  end
  -- read import rules
  local import_config_list = {}
  rv, err = pcall(config_read_list, import_config_list, f_list)
  if not rv then
    import_set_error(import_mapdata, format("read import list failed (%s)", get_error_info(err) or "?"))
    import_config_list = nil
  end
  -- cleanup
  f_list:close()
  -- check if read failed
  if not import_config_list then return end

  -- read import data
  import_mapdata.info = "reading import data"
  rv, err = pcall(import_read_data, import_data, import_mapdata.location .. import_mapdata.filename)
  if not rv then
    import_set_error(import_mapdata, format("read import data failed (%s)", get_error_info(err) or "?"))
    return
  end

  -- NG-85826: check BUILDVERSION
  if import_data.header["BUILDVERSION"] then
	import_mapdata.info = "checking buildversion"
	rv, err = pcall(import_check_buildversion, import_data)
	if not rv then
      import_set_error(import_mapdata, format("buildversion check faild (%s)", get_error_info(err) or "?"))
      return
    end
 end
  
  -- check signature if present
  if import_data.header["SIGNATUREKEY"] then
    import_mapdata.info = "checking signature"
    rv, err = pcall(import_check_signature, import_data)
    if not rv then
      import_set_error(import_mapdata, format("signature check failed (%s)", get_error_info(err) or "?"))
      return
    end
  elseif not check_import_unsigned() then -- check if unsigned import is allowed
    import_set_error(import_mapdata, "unsigned import not allowed")
    return
  end

  -- decrypt ciphertext if present
  if import_data.header["CIPHERKEY"] then
    import_mapdata.info = "decrypting import data"
    rv, err = pcall(import_decrypt_data, import_data)
    if not rv then
      import_set_error(import_mapdata, format("decrypt import data failed (%s)", get_error_info(err) or "?"))
      return
    end
  elseif not check_import_plaintext() then -- check if unencrypted import is allowed
    import_set_error(import_mapdata, "plaintext import not allowed")
    return
  end

  -- parse raw content
  import_mapdata.info = "parsing import content"
  rv, err = pcall(import_parse_content, import_data)
  if not rv then
    import_set_error(import_mapdata, format("parse import content failed (%s)", get_error_info(err) or "?"))
    return
  end

  -- filter config data with import list
  import_mapdata.info = "filtering config data"
  rv, err = pcall(import_filter_configdata, import_data.config, import_config_list)
  if not rv then
    import_set_error(import_mapdata, format("filter config data failed (%s)", get_error_info(err) or "?"))
    return
  end
  -- cleanup
  import_config_list = nil

  -- apply import data
  import_mapdata.info = "applying config data"
  rv, err = pcall(import_apply_configdata, import_data.config)
  if not rv then
    import_set_error(import_mapdata, format("apply config data failed (%s)", get_error_info(err) or "?"))
    return
  end

  import_mapdata.state = "Complete"
  import_mapdata.info = "import succesfully completed"
end

-- reset state and info
function M.import_reset(import_mapdata)
  import_mapdata.state = "None"
  import_mapdata.info = ""
end

function M.import_init(location)
  local import_mapdata = {}
  M.import_reset()
  if location then
    import_mapdata.location = location
  else
    import_mapdata.location = import_location
  end
  return import_mapdata
end

function M.import_start(import_mapdata)
  if not import_mapdata.filename or import_mapdata.filename == "" then
    import_set_error(import_mapdata, "invalid filename")
    return
  end

  uci_cursor = uci.cursor()
  import_execute(import_mapdata)
  uci_cursor:close()
  uci_cursor = nil
end

return M
