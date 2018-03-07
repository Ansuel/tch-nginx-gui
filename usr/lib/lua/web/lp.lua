----------------------------------------------------------------------------
-- Lua Pages Template Processor.
----------------------------------------------------------------------------

local error, loadstring, ipairs =
      error, loadstring, ipairs
local tinsert, tremove = table.insert, table.remove
local open = io.open

local lp_translate = require("web.template").translate

-- the name of the directory from which files can be include()'ed
-- !! should be outside of the document root for security reasons !!
local includepath

local function setpath(path)
  includepath = path
end

----------------------------------------------------------------------------
-- Internal compilation cache.
local cache = {}
local max_cache_size = 20

----------------------------------------------------------------------------
-- Set the size of the template cache.
-- @param size Number of entries (>= 0) to keep in the cache.
----------------------------------------------------------------------------
local function setcachesize(size)
  if size < 0 then
    error("cache size must be >= 0", 2)
  end
  -- if we're shrinking then throw out any excess elements
  if size < max_cache_size and #cache > size then
    for i = size + 1, #cache do
      cache[i] = nil
    end
  end
  max_cache_size = size
end

----------------------------------------------------------------------------
-- Flush the template cache.
----------------------------------------------------------------------------
local function flush()
  cache = {}
end

local function translate(template)
  local translated = template:match("^--pretranslated")
  local translated_string
  if translated then
    translated_string = template
  else
    translated_string = lp_translate(template)
  end
  return translated_string
end

----------------------------------------------------------------------------
-- Translates a template into a Lua function.
-- Does NOT execute the resulting function.
-- The given template is first translate to Lua. Then the resulting source
-- code is compiled into a Lua function.
-- If the given template starts with '--pretranslated' the translation to Lua
-- source code is skipped.
-- @param template String with the template to be translated.
-- @param chunkname String with the name of the chunk, for debugging purposes.
-- @return Function with the resulting translation.
-- @scope internal
----------------------------------------------------------------------------
local function compile (template, chunkname)
  local translated_string = translate(template)
  local f, err = loadstring(translated_string, chunkname)

  if not f then
    error(err, 0)
  end

  return f
end

----------------------------------------------------------------------------
-- get compile lp file from cache.
-- Retrieving an entry from the cache will also move it to the from of the
-- mru list
-- @param filename String with the name of the file containing the template.
-- @return the cached lp entry or nil if not present.
-- @scope internal
----------------------------------------------------------------------------
local function getFromCache(filename)
  for position, entry in ipairs(cache) do
    if entry.filename == filename then
      -- entry already exists, move it to pos 1 of table (most recently used)
      if position ~= 1 then
        entry = tremove(cache, position)
        tinsert(cache, 1, entry)
      end
      return entry
    end
  end
end

----------------------------------------------------------------------------
-- put a compiled lp into the cache
-- @param entry The compiles lp object
-- @scope internal
----------------------------------------------------------------------------
local function putInCache(entry)
  if max_cache_size > 0 then
    -- there is a cache we can insert to
    -- If cache is full clear oldest entry (which is at the end)
    if #cache >= max_cache_size then
      tremove(cache)
    end

    -- Insert new entry on position one (as it is the most recently used)
    tinsert(cache, 1, entry)
  end
end

----------------------------------------------------------------------------
-- read the contents of a file
-- @param filename String with the filename
-- @return the contents of the file as a string or nil plus errmsg in case
--   of error
-- @scope internal
----------------------------------------------------------------------------
local function readFile(filename)
  local fh, err = open(filename, "r")
  if not fh then
    return nil, err
  end
  local src = fh:read("*a")
  fh:close()
  return src
end

----------------------------------------------------------------------------
-- Translates a template in a given file.
-- The translation creates a Lua function which will be executed. Reuses a
-- cached translation if available.
-- @param filename String with the name of the file containing the template.
-- @param chunkname String to be used as chunkname when loading the file.
-- @return the translated code
----------------------------------------------------------------------------
local function load(filename, chunkname)
  local entry = getFromCache(filename)
  if not entry then
    local src = readFile(filename)
    entry = {
      filename = filename,
      content = src and compile(src, chunkname or filename)
    }
    putInCache(entry)
  end
  return entry.content
end

----------------------------------------------------------------------------
-- Includes the given file at the location in the current document where
-- it is called.
-- @param filename The name of the file to be included relative to the
--                 include directory.
----------------------------------------------------------------------------
local function include (filename)
  local content = load(includepath .. filename, filename)
  -- include the specified filename, use the function environment
  -- of the function specifying the include.
  setfenv(content,getfenv(2))
  content()
end


local M = {
  setpath = setpath,
  setcachesize = setcachesize,
  flush = flush,
  load = load,
  include = include,
  translate = translate,
}
return M
