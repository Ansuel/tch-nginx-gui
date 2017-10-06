--------------------------------------------------------------------------------
--  Tainted strings.
--
--  In short: it works by wrapping tainted strings in a small userdata
--  with appropriate metamethods to act like a regular string.
--  It also wraps the standard string library functions so they work
--  correctly when fed these tainted string objects.
--
--  !!! Important notes: !!!
--  * This requires a modified VM. Normally the comparison between two
--    variables of different types is by definition false. This prevents
--    a comparison like 's1 == s2' if one of the two is a primitive string
--    and the other a tainted string object.
--    The VM needs to be changed to invoke metamethods when one argument is
--    a string and the other a userdata.
--  * Another useful core modification is letting tonumber() retry the
--    conversion on the return value of a __tonumberstr metamethod when present
--    instead of giving up if the argument is not a number or real string.
--  * Using strings as keys in tables is not completely transparent.
--      local t = { foo = "bar" }
--      local s1 = "foo"
--      local s2 = string.taint("foo")
--      assert(t[s1] == t[s2]) --> will fire !!
--      local t2 = { [s2] = "bar" }
--      assert(t2[s1] == t2[s2]) --> will fire !!
--    A way to solve this is by adding a metatable to the table with an
--    appropriate __index metamethod that retries the table lookup with the
--    untainted or tainted version of the key, respectively.
--    Such metatables are made available for your use from this module; see
--    the untaint_mt and taint_mt fields in the module table.
--  * Use of tainted strings is also not transparent when passed to functions
--    that implicitly assume to only receive primitive strings.
--    Typical example is io.write() which only wants strings or numbers.
--  * Note that tostring() on a tainted string is a no-op. To remove the taint
--    you have to call the untaint() function. Be careful when using it as you
--    kinda defeat the purpose of string tainting.
--  * The metatable on the string type is not changed. This means that if you
--    call a string library function via the OO notation you will immediately
--    use the correct function instead of having to pass through the tainting
--    aware functions.
--    string.find(s, "foo") works for a regular and tainted 's' but it's less
--    efficient if 's' is a regular string. Using s:find("foo") is better and
--    will automatically use the normal string functions or the tainting aware
--    ones depending on 's'. One disadvantage of using the OO notation is that
--    you can't use a tainted string as argument to a call on a regular string.
--    If 's' is a regular string but one of your arguments can be tainted then
--    just call the function through the string library instead of via the
--    OO notation.
--  * The string library table itself is not replaced. We overwrite the string
--    functions with tainting-aware ones. The reason for this is that under
--    ngx_lua each request gets its own _G. If we set _G.string then that is
--    not visible in another request.
--------------------------------------------------------------------------------

local newproxy, tostring, ipairs, type, unpack, rawequal, rawget, error =
      newproxy, tostring, ipairs, type, unpack, rawequal, rawget, error

-- table mapping the tainted string object (proxy) to the actual string
local strings = {}
-- table mapping a string to a tainted string object (proxy) so we can
-- reuse an existing proxy instead of creating a new one each time
-- (incidentally this makes comparing two tainted strings a simple
-- pointer comparison instead of having to pass through __eq metamethod)
local proxies = {}
-- make our mapping tables appropriately weak so the proxy objects
-- can be properly GC'd
setmetatable(strings, { __mode = "k" })
setmetatable(proxies, { __mode = "v" })
local tainted = newproxy(true)   -- tainted object proxy
local mt = getmetatable(tainted)   -- metatable with operations on object proxy
local string = string   -- the original string library functions

local function get_proxy(s)
  local p = proxies[s]
  if not p then
    p = newproxy(tainted)
    strings[p] = s
    proxies[s] = p
  end
  return p
end

mt.__index = string
mt.__tostring = function(o)
  return "tainted string"
end
mt.__tonumberstr = function(o)
  return strings[o]
end
mt.__len = function(o)
  return #strings[o]
end
mt.__eq = function(o1, o2)
  return (strings[o1] or o1) ==
         (strings[o2] or o2)
end
mt.__lt = function(o1, o2)
  return (strings[o1] or o1) <
         (strings[o2] or o2)
end
mt.__le = function(o1, o2)
  return (strings[o1] or o1) <=
         (strings[o2] or o2)
end
mt.__concat = function(o1, o2)
  o1 = strings[o1] or o1
  o2 = strings[o2] or o2
  return get_proxy(o1 .. o2)
end
mt.__add = function(o1, o2)
  o1 = strings[o1] or o1
  o2 = strings[o2] or o2
  return o1 + o2
end
mt.__sub = function(o1, o2)
  o1 = strings[o1] or o1
  o2 = strings[o2] or o2
  return o1 - o2
end
mt.__mul = function(o1, o2)
  o1 = strings[o1] or o1
  o2 = strings[o2] or o2
  return o1 * o2
end
mt.__div = function(o1, o2)
  o1 = strings[o1] or o1
  o2 = strings[o2] or o2
  return o1 / o2
end
mt.__mod = function(o1, o2)
  o1 = strings[o1] or o1
  o2 = strings[o2] or o2
  return o1 % o2
end
mt.__pow = function(o1, o2)
  o1 = strings[o1] or o1
  o2 = strings[o2] or o2
  return o1 ^ o2
end
mt.__unm = function(o)
  o = strings[o] or o
  return -o
end

-----------------------------------------------------------
-- Add a taint() method to the string library.
-- NOTE: this returns a new object that should be used
--       instead of s!! The following doesn't work:
--       s = "foo"
--       s:taint() --> this doesn't change s
--       s = s:taint() --> correct
-----------------------------------------------------------
function string.taint(s)
  if strings[s] then
    return s
  end
  s = tostring(s)
  return get_proxy(s)
end

-----------------------------------------------------------
-- Add an untaint() method to the string library.
-- NOTE: this is a no-op when called on something not a
--       tainted string. When called on a tainted string
--       it returns a clean (real) string and doesn't
--       change the argument.
-- TODO: perhaps not stuff this in the string table where it's
--       easy to find and abuse but only in the module table
-----------------------------------------------------------
function string.untaint(o)
  return strings[o] or o
end

-----------------------------------------------------------
-- Add an istainted() method to the string library.
-----------------------------------------------------------
function string.istainted(o)
  return (strings[o] ~= nil)
end

-- The __index metamethod of the metatable of the string type
-- can't point to the original string table because we will
-- overwrite those functions. Instead create a new __index table
-- with the original string functions. We do want to add taint(),
-- untaint() and istainted() so we do it here after those functions
-- were added to the string table.
local str__index = {}
for k, v in pairs(string) do
  str__index[k] = v
end
getmetatable("").__index = str__index

-----------------------------------------------------------
-- Generator that creates tainting-aware wrapper functions
-- for standard string library functions.
-- Only suitable for functions that just return a new string.
-----------------------------------------------------------
local function generate(f)
  return function(o, ...)
    local s = strings[o]
    if s then
      local v = f(s, ...)
      return get_proxy(v)
    end
    return f(o, ...)
  end
end

-----------------------------------------------------------
local byte = string.byte
string.byte = function(s, i, j)
  s = strings[s] or s
  return byte(s, i, j)
end

-----------------------------------------------------------
-- Strictly speaking any string created with string.char
-- should be tainted to be 100% sure.
-- For now just leave it as I don't really see when we
-- would use that function.

-----------------------------------------------------------
local dump = string.dump
string.dump = function(f)
  return get_proxy(dump(f))
end

----------------------------------------------------------
local find = string.find
function string.find(o, pattern, init, plain)
  -- Pattern can also be a tainted string. Just untaint it and don't
  -- necessarily taint any results.
  pattern = strings[pattern] or pattern
  local s = strings[o]
  if s then
    local t = { find(s, pattern, init, plain) }
    if #t == 0 then  -- no match so just return nil
      return nil
    end
    if #t > 2 then  -- if there was a match and captures then taint the captures
      for i = 3, #t do
        local p = get_proxy(t[i])
        t[i] = p
      end
    end
    return unpack(t)
  end
  return find(o, pattern, init, plain)
end

-----------------------------------------------------------
-- In contrast to the other string library functions this
-- one will escape tainted arguments before using. This
-- means that everything this function returns is safe.
-- The escape function to use can be configured using the
-- set_escape_function() function. It is assumed that the
-- function returns a clean string.
-- By default no escape function is configured meaning an
-- error will be thrown should you try to use string.format()
-- before an escape function is set.
-----------------------------------------------------------
local escape
local function set_escape_function(f)
  escape = f
end

local format = string.format
function string.format(fmt, ...)
  if strings[fmt] then
    error("string.format() called with tainted format string", 2)
  end
  local t = { ... }
  -- check if one of the arguments is tainted
  for i,v in ipairs(t) do
    local s = strings[v]
    if s then
      t[i] = escape(s)
    end
  end
  return format(fmt, unpack(t))
end

-----------------------------------------------------------
local gmatch = string.gmatch
function string.gmatch(o, pattern)
  -- Pattern can also be a tainted string. Just untaint it and don't
  -- necessarily taint any results.
  pattern = strings[pattern] or pattern
  local s = strings[o]
  if s then
    local it = gmatch(s, pattern)
    return function()
      local t = { it() }
      for i,v in ipairs(t) do
        local p = get_proxy(v)
        t[i] = p
      end
      return unpack(t)
    end
  end
  return gmatch(o, pattern)
end

-----------------------------------------------------------
local gsub = string.gsub
function string.gsub(s, pattern, repl, n)
  -- Pattern can also be a tainted string. Just untaint it and don't
  -- necessarily taint any results.
  pattern = strings[pattern] or pattern
  local real_s = strings[s] or s
  local taint = not rawequal(real_s, s)
  local real_repl
  local repl_type = type(repl)

  if repl_type == "string" then
    real_repl = repl
  elseif repl_type == "userdata" then
    real_repl = strings[repl] or repl
    taint = taint or (not rawequal(real_repl, repl))
  elseif repl_type == "table" then
    real_repl = function(key)
      local res = repl[key]
      local r = strings[res] or res
      if not rawequal(r, res) then
        taint = true
      end
      return r
    end
  elseif repl_type == "function" then
    real_repl = function(...)
      local res
      if taint then
        -- the input string to gsub is tainted, so in order to prevent
        -- unwanted untainting due to the misuse of gsub, the arguments
        -- to the replacement function must be tainted.
        local args = {...}
        for i, arg in ipairs(args) do
          args[i] = arg:taint()
        end
        res = repl(unpack(args))
      else
        res = repl(...)
      end
      local r = strings[res] or res
      if not rawequal(r, res) then
        taint = true
      end
      return r
    end
  end
  local res, matches = gsub(real_s, pattern, real_repl, n)
  if taint then
    local p = get_proxy(res)
    return p, matches
  end
  return res, matches
end

-----------------------------------------------------------
local len = string.len
string.len = function(s)
  s = strings[s] or s
  return len(s)
end

-----------------------------------------------------------
string.lower = generate(string.lower)

-----------------------------------------------------------
local match = string.match
function string.match(o, pattern, init)
  -- Pattern can also be a tainted string. Just untaint it and don't
  -- necessarily taint any results.
  pattern = strings[pattern] or pattern
  local s = strings[o]
  if s then
    local t = { match(s, pattern, init) }
    if #t == 0 then   -- no match so just return nil
      return nil
    end       -- if there was a match then taint the returned match or captures
    for i = 1, #t do
      local p = get_proxy(t[i])
      t[i] = p
    end
    return unpack(t)
  end
  return match(o, pattern, init)
end

-----------------------------------------------------------
string.rep = generate(string.rep)

-----------------------------------------------------------
string.reverse = generate(string.reverse)

-----------------------------------------------------------
string.sub = generate(string.sub)

-----------------------------------------------------------
string.upper = generate(string.upper)


return {
  set_escape_function = set_escape_function,
  untaint_mt = { __index = function(t, k)
                   return rawget(t, strings[k])
                 end },
  taint_mt = { __index = function(t, k)
                 return rawget(t, proxies[k])
               end }
}
