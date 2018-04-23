-- This is the interface to loading MO files

-- A single webui package corresponds to a single gettext textdoamin and thus
-- a single .mo file, containing all translations for the package.

-- for the mo file format see:
--   http://www.gnu.org/software/gettext/manual/html_node/MO-Files.html

local open = io.open
local string = string
local format = string.format
local error = error
local pairs = pairs

local M = {}

--- get a 4 byte value from the data
-- @param data the string containing the binary data
-- @param offset the ZERO based offset in the data
-- @param endian the endianess, either 'big' or 'little'
-- @returns the value of the 4 byte unsigned integer at offset
--   or nil plus error msg on error
local function get_uint32(data, offset, endian)
    endian = endian or 'little'

    -- retrieve the bytes, assume little endian as that is the most common case
    -- (files created on x86)
    local b4, b3, b2, b1 = data:byte(offset+1, offset+4)

    if not (b1 and b2 and b3 and b4) then
        return nil, format('offset %d out of range', offset)
    end

    if endian=='big' then
        b1, b2, b3, b4 = b4, b3, b2, b1
    elseif endian~='little' then
        return nil, format('invalid endian value "%s"', endian)
    end

    return (b1 * 0x1000000) + (b2 * 0x10000) + (b3 * 0x100) + b4
end

-- the magic number bytes signaling an MO file (in big endian order)
local MAGIC = string.char( 0x95, 0x04, 0x12, 0xDE )

-- the magic expressed as a number. If the magic number in the file was read
-- with the correct endianess, this is the value.
local MO_MAGIC = get_uint32(MAGIC, 0, 'big')

-- the magic number if the bytes were read in reversed order
-- If the magic number in the file was read with the wrong endianess, this
-- would be the value
local MO_MAGIC_REVERSE = get_uint32(MAGIC, 0, 'little')

-- Note that we cannot define the above magic numbers directly from a hex
-- number (like 0x950412DE) because of some weirdness in the LNUM patch.
-- (the number becomes singed and negative, not the positive number wanted)

--- get the header info
-- @param data String, the binary data
--   this must be at least the first 20 bytes of the file
-- @returns the number of strings, start of original strings and start of
--   the translated string lists and the endianess of the file
--   or nil, err message in case of error
-- This function checks the magic and revision.
local function readHeader(data)
    local endian = 'little' -- common case, MO generated on x86
    local magic, err = get_uint32(data, 0, endian)
    if not magic then
        return nil, err
    end
    if magic==MO_MAGIC_REVERSE then
        -- endianess is different
        endian = 'big'
    elseif magic~=MO_MAGIC then
        return nil, "not a valid MO file, invalid magic"
    end

    local revision = get_uint32(data, 4, endian)
    if revision ~= 0 then
        return nil, "unknown MO revision %d"
    end

    local nstrings = get_uint32(data, 8, endian)
    local orig_offset = get_uint32(data, 12, endian)
    local trans_offset = get_uint32(data, 16, endian)

    -- ensure all expected values are present
    if not(nstrings and orig_offset and trans_offset) then
        return nil, "not enough data"
    end

    return nstrings, orig_offset, trans_offset, endian
end

--- load MO file
-- @param infile (string) the data contained in the file
-- @returns table with the strings and the number of strings
-- or nil plus error msg on failure
local function loadMO(infile)
    local moStrings = {}

    local nstrings, orig_offset, trans_offset, endian = readHeader(infile)
    if not nstrings then
        return nil, orig_offset --the error
    end
    for i=0,nstrings-1 do
        local offset, length, start
        -- note that pointers are zero based so we must add 1 to get the correct
        -- start value
        -- original string
        offset = orig_offset + (i*8)
        length = get_uint32(infile, offset, endian)
        start = get_uint32(infile, offset+4, endian)+1
        local orig = infile:sub(start, start+length-1)
        -- the strings for ngettext may become concatenated with NUL
        -- in between. 
        -- We only need the first string.
        if orig:find('%z') then
            orig = orig:match('^([^%z]*)')
        end
        -- translated string
        offset = trans_offset + (i*8)
        length = get_uint32(infile, offset, endian)
        start = get_uint32(infile, offset+4, endian) + 1
        local trans = infile:sub(start, start+length-1)
        if trans:find('%z') then
            -- process plurals, they are separated by NUL bytes
            -- epxlicitly add a NUL byte at the end. This simplifies the
            -- match expression.
            trans = trans .. '\0'
            local multi = {}
            for v in trans:gmatch('([^%z]*)%z') do
                multi[#multi+1] = v
            end
            trans = multi
        end
        moStrings[orig] = trans
    end

    return moStrings, nstrings
end

--- Load the given MO file
-- @param filename String, the name of the file to load
-- @returns a table with the translations
--   or nil plus error msg
function M.load(filename)
    local f_in, err = open(filename)
    if not f_in then
        return nil, err
    end
    local data = f_in:read('*a')
    f_in:close()
    if not data then
        return nil, "failed to read data"
    end
    return loadMO(data)
end

--- Get the name of the language in the MO file
-- @param filename String name of the MO file
-- @returns the value of the Language: header, or nil
-- The "Language:" header is not standard and must be added in the PO file.
-- There seems to be no other way to get a descriptive name for the language.
function M.getLanguage(filename)
    local f, err = open(filename)
    if not f then
        -- no error message as this is not real an error
        return nil
    end
    local data = f:read(20)
    local n, O, T, E = readHeader(data)
    if not n then
        return nil, O
    end
    if n==0 then
        return nil, "no strings found"
    end

    -- get the offset of the 'translation' for ""
    -- (strings are sorted, so this is the first one)
    -- This contains the metadata

    f:seek("set", T)
    data = f:read(8)
    local start
    start, err = get_uint32(data, 4, E)
    if not start then
        return nil, err
    end
    local length
    length, err = get_uint32(data, 0, E)
    if not length then
        return nil, err
    end

    -- get the string
    f:seek("set", start)
    data = f:read(length)

    local lang = data:match('\nLanguage%-Name:%s*([^\n]*)\n')
    if lang then
        -- remove trailing spaces
        lang = lang:gsub('%s+$', '')
    end
    return lang
end

return M
