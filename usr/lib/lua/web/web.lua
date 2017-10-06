local taint, istainted, untaint, match, format, byte, sub
local select, type, unpack, pairs, ipairs, getfenv, loadfile =
      select, type, unpack, pairs, ipairs, getfenv, loadfile

-- HTML escape function
-- TODO: nginx has a C implementation in ngx_string.c; to be investigated
-- if it is faster if we bind that to Lua and use it
local entities = { ['<'] = "&lt;", ['>'] = "&gt;", ['&'] = "&amp;",
                   ['"'] = "&quot;", ["'"] = "&#39;", ['/'] = "&#47;" }
--- Escapes certain characters in the given string according to
-- the HTML escaping rules.
-- Note that this only securely escapes dangerous characters in HTML
-- context; other contexts are not fully protected!
-- For more info see https://www.owasp.org/index.php/XSS_%28Cross_Site_Scripting%29_Prevention_Cheat_Sheet
-- @string s The string to escape.
-- @treturn string The escaped string.
local function html_escape(s)
  -- If 's' is tainted then gsub() will return a tainted string.
  -- We're sure the resulting string is safe so let's untaint it.
  return untaint(s:gsub('[<>&"\'/]', entities))
end

-- Load the 'lp' module before the tainting module so
-- it gets the unmodified string table. That way it can take
-- local references to the original string functions for
-- optimal performance.
local lp = require("web.lp")

-- Load the tainting module. From now on all string.* functions
-- are tainting-aware wrappers around the original ones.
local tainting = require("web.taint")
tainting.set_escape_function(html_escape)

-- Now instruct the datamodel module to taint all values.
require("datamodel").enable_tainting()

local intl = require 'web.intl'

taint,        istainted,        untaint,        match,        format,        byte,        sub =
string.taint, string.istainted, string.untaint, string.match, string.format, string.byte, string.sub

-- Now wrap some ngx. functions to make them tainting-aware:
-- - Functions to access data should taint unsafe data.
-- - Functions outputting data should check whether the data
--   is tainted and possibly escape it.
local ngx = ngx

do
  -- ngx.say() and ngx.print()
  local function escape_table(t)
    for i, s in ipairs(t) do
      if istainted(s) then
        t[i] = html_escape(s)
      elseif type(s) == "table" then
        t[i] = escape_table(s)
      end
    end
    return t
  end
  local function ngx_output(f, ...)
    local nargs = select("#", ...)
    -- unroll for 1 or 2 arguments, which is very common
    if nargs == 1 then
      local arg = ...
      if istainted(arg) then
        return f(html_escape(arg))
      end
      if type(arg) == "table" then
        return f(escape_table(arg))
      end
      return f(arg)
    elseif nargs == 2 then
      local arg1, arg2 = ...
      if istainted(arg1) then
        arg1 = html_escape(arg1)
      elseif type(arg1) == "table" then
        arg1 = escape_table(arg1)
      end
      if istainted(arg2) then
        arg2 = html_escape(arg2)
      elseif type(arg2) == "table" then
        arg2 = escape_table(arg2)
      end
      return f(arg1, arg2)
    else
      local args = { ... }
      for i = 1, nargs do
        local s = args[i]
        if istainted(s) then
          args[i] = html_escape(s)
        elseif type(s) == "table" then
          args[i] = escape_table(s)
        end
      end
      return f(unpack(args))
    end
  end
  local ngx_print = ngx.print
  local ngx_say = ngx.say
  ngx.print = function(...)
    return ngx_output(ngx_print, ...)
  end
  ngx.say = function(...)
    return ngx_output(ngx_say, ...)
  end

  -- ngx.req.get_uri_args() and ngx.req.get_post_args()
  local function taint_table(t)
    -- TODO: also taint the keys?
    for k, v in pairs(t) do
      local v_t = type(v)
      if v_t == "table" then
        for i, v2 in ipairs(v) do
          v[i] = taint(v2)
        end
      elseif v_t ~= "boolean" then
        t[k] = taint(v)
      end
    end
    return t
  end

  local get_uri_args = ngx.req.get_uri_args
  ngx.req.get_uri_args = function(...)
    return taint_table(get_uri_args(...))
  end

  local get_post_args = ngx.req.get_post_args
  ngx.req.get_post_args = function(...)
    ngx.req.read_body()
    local post_data, err = get_post_args(...)
    if post_data then
      -- check CSRF token
      local session = ngx.ctx.session
      session:checkCSRFtoken(post_data.CSRFtoken)  -- does not return on failure
      post_data = taint_table(post_data)
    end
    return post_data, err
  end

  -- ngx.var.*
  local ngx_var_mt = getmetatable(ngx.var)
  local var_index = ngx_var_mt.__index
  local var_newindex = ngx_var_mt.__newindex
  ngx_var_mt.__index = function(t, k)
    local v = var_index(t, k)
    if v then
      return taint(v)
    end
  end
  ngx_var_mt.__newindex = function(t, k, v)
    return var_newindex(t, k, untaint(v))
  end

  -- ngx.(un)escape_uri()
  local escape_uri = ngx.escape_uri
  ngx.escape_uri = function(s)
    local tainted = istainted(s)
    s = escape_uri(untaint(s))
    if tainted then
      s = taint(s)
    end
    return s
  end

  local unescape_uri = ngx.unescape_uri
  ngx.unescape_uri = function(s)
    local tainted = istainted(s)
    s = unescape_uri(untaint(s))
    if tainted then
      s = taint(s)
    end
    return s
  end
end

local M = { html_escape = html_escape }

--- Output a formatted string.
-- This is a simple utility function that combines `ngx.print` and
-- `string.format`.
function M.printf(...)
  ngx.print(format(...))
end

local function log_gettext_error(msg)
    ngx.log(ngx.NOTICE, msg)
end

-- get a content render function for the given filename
-- returns content renderer function and content mime type
--   or nil if not renderer could be found
local function getContentRenderer(filename)
  local ext = filename:match("%.([^.]+)$")
  local renderer
  local mimetype = "text/html"
  if ext == "lp" then
    renderer = lp.load(filename, untaint(ngx.var.uri))
  elseif ext == "lua" then
    mimetype = "text/plain"
    renderer = loadfile(filename)
  end
  return renderer, mimetype
end

-- setup gettext support for a renderer
local function insertGettext(renderer)
  local headers = ngx.req.get_headers()
  local cookies = headers['cookie']
  local cookielanguage
  if cookies then
    cookielanguage = match(cookies, 'webui_language=([%a%-]+);?')
  end
  local language = intl.findLanguage('webui-core', cookielanguage, headers['accept-language'])
  ngx.header['Content-Language'] = language
  local env = getfenv(renderer)
  local gettext = env.gettext or intl.load_gettext(log_gettext_error)
  env.gettext = gettext
  env.T = gettext.gettext
  env.N = gettext.ngettext
  gettext.language(language)
end

--- Process the request based on the file extension.
-- If no explicit filename is given then we ask nginx
-- which physical file is requested and use that.
-- @string[opt=ngx.var.request_filename] filename The full path to the file
--   on the filesystem that corresponds to the resource being requested.
function M.process(filename)
  filename = untaint(filename or ngx.var.request_filename)

  -- our response must not be cached because it's dynamically generated content
  ngx.header.cache_control = "no-cache"

  local content, mimetype = getContentRenderer(filename)
  if not content then
    ngx.exit(404)
  end
  ngx.header.content_type = mimetype

  insertGettext(content)

  -- render it
  content()
end

-- Parsing of 'Cookie:' header.
-- Based on https://github.com/cloudflare/lua-resty-cookie
-- but returns all the values for a cookie in case multiple are present.
do
  local EQUAL = byte("=")
  local SEMICOLON = byte(";")
  local SPACE = byte(" ")
  local HTAB = byte("\t")

  local function store_cookie(t, key, value)
    value = taint(value)
    local curr = t[key]
    if not curr then
      t[key] = value
    else
      if type(curr) == "table" then
        curr[#curr + 1] = value
      else
        t[key] = { curr, value }
      end
    end
  end

  --- Parses the 'Cookie:' header.
  -- @treturn table Cookie names are the keys and the values are either a string
  --   (when there's only one value) or an array of strings.
  function M.get_cookies()
    local EXPECT_KEY = 1
    local EXPECT_VALUE = 2
    local EXPECT_SP = 3

    local cookies = {}
    local text_cookie = untaint(ngx.var.http_cookie)
    if not text_cookie then
      return cookies
    end
    local len = #text_cookie
    local state = EXPECT_SP
    local i = 1
    local j = 1
    local key, value

    while j <= len do
      if state == EXPECT_KEY then
        if byte(text_cookie, j) == EQUAL then
          key = sub(text_cookie, i, j - 1)
          state = EXPECT_VALUE
          i = j + 1
        end
      elseif state == EXPECT_VALUE then
        if byte(text_cookie, j) == SEMICOLON or
           byte(text_cookie, j) == SPACE or
           byte(text_cookie, j) == HTAB then
          value = sub(text_cookie, i, j - 1)
          store_cookie(cookies, key, value)
          key, value = nil, nil
          state = EXPECT_SP
          i = j + 1
        end
      elseif state == EXPECT_SP then
        if byte(text_cookie, j) ~= SPACE and
           byte(text_cookie, j) ~= HTAB then
          state = EXPECT_KEY
          i = j
          j = j - 1
        end
      end
      j = j + 1
    end

    if key ~= nil and value == nil then
      store_cookie(cookies, key, sub(text_cookie, i))
    end

    return cookies
  end
end

local cached_isDemoBuild

function M.isDemoBuild()
  if cached_isDemoBuild == nil then
    local data = require("datamodel").get("uci.version.version.@version[0].mask")
    if data then
      local versionmask = data[1].value
      cached_isDemoBuild = tonumber(versionmask:sub(3,3)) % 2 == 1 or versionmask:sub(4,4) == '9'
    else
      cached_isDemoBuild = true
    end
  end
  return cached_isDemoBuild
end

return M
