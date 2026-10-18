-- Read-only CLI harness: real endpoint/datamodel work, not HTTP/session timing.
-- Run with the modem's native Lua: lua benchmark-dashboard.lua
-- Does not install endpoints, reload services or persist session/configuration data.
assert(_G.ngx == nil, 'Run from the Lua CLI, never inside nginx')
package.path = '/www/lua/?.lua;' .. package.path
local args = {}
local function noop() end
ngx = {header = {['Content-Language'] = 'en-us'},
  ctx = {session = {retrieve = function() return {} end, store = noop}},
  req = {get_method = function() return 'POST' end,
    get_uri_args = function() return args end,
    get_post_args = function() return {} end, read_body = noop},
  var = setmetatable({}, {__index = function() end, __newindex = rawset}),
  print = noop, say = noop, exit = noop, log = noop, HTTP_OK = 200,
  escape_uri = function(s) return s end, unescape_uri = function(s) return s end}
require('web.web')
gettext = require('web.intl').load_gettext(noop)
gettext.language('en-us')
T = gettext.gettext
local proxy = require('datamodel')
local calls = 0
local iterations = 30
for _, name in ipairs({'get', 'getPN'}) do
  local original = proxy[name]
  proxy[name] = function(...) calls = calls + 1; return original(...) end
end
local function uptime()
  local f = assert(io.open('/proc/uptime'))
  local value = assert(tonumber(f:read('*n'))); f:close(); return value
end
local failed = false
for _, entry in ipairs({
  {'gateway', 'cpuload.lua', {}},
  {'wan', 'internet.lua', {}},
  {'xdsl', 'internet.lua', {datatype = 'xdsl'}},
  {'devices', 'connected_device.lua', {}},
  {'ports', 'port_status.lua', {}},
  {'telephony', 'mmpbx_status.lua', {}},
}) do
  args = entry[3]
  local fn = assert(loadfile('/www/docroot/ajax/' .. entry[2]))
  local ok, err = pcall(fn)
  if not ok then
    failed = true
    print(entry[1], 'HARNESS_ERROR', string.untaint(tostring(err)))
  else
    calls = 0
    local wall, cpu = uptime(), os.clock()
    for i = 1, iterations do assert(pcall(fn)) end
    print(string.format('%s wall_ms=%.2f cpu_ms=%.2f dm_calls=%.1f n=%d',
      entry[1], (uptime()-wall)*1000/iterations,
      (os.clock()-cpu)*1000/iterations, calls/iterations, iterations))
  end
end
if failed then os.exit(1) end
