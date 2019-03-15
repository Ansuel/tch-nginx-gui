-- This is the interface to loading MO files

-- A single webui package corresponds to a single gettext textdoamin and thus
-- a single .mo file, containing all translations for the package.

-- for the mo file format see:
--   http://www.gnu.org/software/gettext/manual/html_node/MO-Files.html

local open = io.open
local concat = table.concat
local error = error
local pairs = pairs

local M = {}

--- Load the given PO file
-- @param filename String, the name of the file to load
-- @returns a table with the translations
--   or nil plus error msg
function M.load(filename)
    local f_in, err = open(filename)
    if not f_in then
        return nil, err
    end
    local line
	local check_multiline = ""
	local moStrings = {}
	local orig, trans, plural, pluralstring = {}, {}, {}, {}
	local plural_String = false
	local nstrings = 0
	local empty_trans = false
	for line in f_in:lines() do
		if line == "" or line:match("^msg[A-Z]+%s") then
			if orig[1] then
				nstrings = nstrings + 1
			end
			if trans[1] then
				if not ( concat(trans) == "" ) then
					moStrings[concat(orig)] = concat(trans)
				else
					nstrings = nstrings - 1
				end
				trans = {}
				orig = {}
			end
			if plural[1] then
				if pluralstring[1] then
					if not ( concat(pluralstring) == "" ) then
						plural[#plural+1] = concat(pluralstring)
					else
						empty_trans = true
					end
					pluralstring = {}
				end
				if ( empty_trans == false ) then
					moStrings[concat(orig)] = plural
				else
					nstrings = nstrings - 1
				end
				orig = {}
				plural = {}
			end
			plural_String = false
			check_multiline = ""
		end
		if ( check_multiline == "msgid" ) and not ( line:match("^msg.+%s\"") ) and not plural_String then
			orig[#orig+1] = line:gsub("\"","",1):sub(0,-2):gsub("\\\"","\"")
		end
		if ( check_multiline == "msgstr" ) and not ( line:match("^msgid%s") ) then
			trans[#trans+1] = line:gsub("\"","",1):sub(0,-2):gsub("\\\"","\"")
		end
		if ( check_multiline == "msgstr_plural" ) and not ( line:match("^msgstr%[") ) then
			pluralstring[#pluralstring+1] = line:gsub("\"","",1):sub(0,-2):gsub("\\\"","\"")
		end
		if line:match("^msgid%s") then
			orig = {}
			orig[#orig+1] = line:gsub("msgid \"",""):sub(0,-2):gsub("\\\"","\"")
			check_multiline = "msgid"
		end
		if line:match("^msgid_plural") then
			plural_String = true
		end
		if line:match("^msgstr%s") then
			trans = {}
			trans[#trans+1] = line:gsub("msgstr \"",""):sub(0,-2):gsub("\\\"","\"")
			check_multiline = "msgstr"
		end
		if line:match("^msgstr%[") then
			if pluralstring[1] then
				plural[#plural+1] = concat(pluralstring)
				pluralstring = {}
			end
			pluralstring[#pluralstring+1] = line:gsub("msgstr%[.*%] \"",""):sub(0,-2):gsub("\\\"","\"")
			check_multiline = "msgstr_plural"
		end
	end
    f_in:close()
	
	-- This make sure the lad line is added to the moStrings
	if trans[1] then
		if not ( concat(trans) == "" ) then
			moStrings[concat(orig)] = concat(trans)
		else
			nstrings = nstrings - 1
		end
	end
	if plural[1] then
		if pluralstring[1] then
			if not ( concat(pluralstring) == "" ) then
				plural[#plural+1] = concat(pluralstring)
			else
				empty_trans = true
			end
			pluralstring = {}
		end
		if ( empty_trans == false ) then
			moStrings[concat(orig)] = plural
		else
			nstrings = nstrings - 1
		end
	end
	
	return moStrings, nstrings
end

--- Get the name of the language in the PO file
-- @param filename String name of the PO file
-- @returns the value of the Language: header, or nil
-- The "Language:" header is not standard and must be added in the PO file.
-- There seems to be no other way to get a descriptive name for the language.
function M.getLanguage(filename)
    local f, err = open(filename)
    if not f then
        -- no error message as this is not real an error
        return nil
    end

    local lang , lines
	for lines in f:lines() do
		if lines:match("Language%-Name:") then
			lang = lines:gsub("\"Language%-Name:%s",""):gsub("\\n\"","")
			break
		end
	end
	f:close()
    return lang or nil
end

return M