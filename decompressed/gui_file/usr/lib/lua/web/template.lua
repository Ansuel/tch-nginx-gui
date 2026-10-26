----------------------------------------------------------------------------
-- Lua Pages Template Processor.
----------------------------------------------------------------------------

local find, format, gsub, sub = string.find, string.format, string.gsub, string.sub
local concat, tinsert = table.concat, table.insert

----------------------------------------------------------------------------
-- functions to do output ('outfunc' expects string or number, 'printfunc'
-- does tostring() so can process anything)
-- TODO: docs say that ngx.print() and ngx.say() are rather expensive. Perhaps
--       we should rewrite the translation of the template to buffer data in
--       a Lua table and only output at the end of a %> block.
local outfunc = "ngx.print"
local printfunc = "ngx.print"

----------------------------------------------------------------------------
-- Builds a piece of Lua code which outputs the (part of the) given string.
-- @param s String.
-- @param i Number with the initial position in the string.
-- @param f Number with the final position in the string (default == -1).
-- @return String with the corresponding Lua code which outputs the part of
--    the string.
-- @scope internal
----------------------------------------------------------------------------
local function out(s, i, f)
    s = sub(s, i, f or -1)
    if s == "" then return s end
    -- we could use `%q' here, but this way we have better control
    s = gsub(s, "([\\\n\'])", "\\%1")
    -- substitute '\r' by '\'+'r' and let `loadstring' reconstruct it
    s = gsub(s, "\r", "\\r")
    return format(" %s('%s'); ", outfunc, s)
end

----------------------------------------------------------------------------
-- Translate the template to Lua code.
-- @param s String to translate.
-- @return String with translated code.
-- @scope internal
----------------------------------------------------------------------------
local function translate(s)
  local res = {}

  local start = 1   -- start of untranslated part in `s'

  while true do
    local ip, fp, exp, code = find(s, "<%%[ \t]*(=?)(.-)%%>", start)
    if not ip then
      break
    end
    tinsert(res, out(s, start, ip-1))
    if exp == "=" then   -- expression?
      tinsert(res, format(" %s(%s);", printfunc, code))
    else  -- command
      tinsert(res, format(" %s ", code))
    end
    start = fp + 1
  end
  tinsert(res, out(s, start))
  return concat(res)
end

return {
	translate = translate
}
