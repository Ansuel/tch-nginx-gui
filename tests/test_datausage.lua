-- Run with firmware Lua as well as local Lua/LuaJIT. All counters are synthetic.
local root = assert(arg[1])
pcall(require, 'web.taint') -- Exercise real tainted strings on the router runtime.
local tainted, handles = {}, {}
local firmwareTaint = string.taint
local originalUntaint = string.untaint
if not firmwareTaint then
  string.untaint = function(value) return tainted[value] or value end
end
local function taint(value)
  if firmwareTaint then return firmwareTaint(value) end
  local token = newproxy and newproxy() or assert(io.tmpfile())
  tainted[token] = value
  handles[#handles+1] = token
  return token
end
local read, write, post, output, emitted, registered = {}, {}, {}, {}, nil, nil
local available, selected, response = true, 'wan', {}
local connection = {call = function(_, object, method, params)
  assert(object == 'datausage' and params.interface)
  if method == 'get' then return response[params.interface] or {} end
  assert(method == 'reset')
  write[#write+1] = params.interface
  response[params.interface].rx_bytes_total = '0'
  response[params.interface].tx_bytes_total = '0'
  return {}
end}
mapper = function(name)
  if name == 'ucihelper' then return {} end
  assert(name == 'ubus')
  return {connect = function() return connection end}
end
register = function(mapping) registered = mapping end
package.preload['mobiled.scripthelpers'] = function() return {
  getUbusData = function(conn, object, method, params)
    local result = {}
    for key,value in pairs(conn:call(object, method, params)) do result[key] = tostring(value) end
    return result
  end,
} end
assert(loadfile(root .. '/usr/share/transformer/mappings/rpc/datausage.interface.map'))()
package.preload.datamodel = function() return {
  get = function(path)
    read[#read+1] = path
    if not available then return nil, 'backend unavailable' end
    if path == 'rpc.datausage_notifier.web_selected_interface' then
      return {{value = taint(selected)}}
    end
    local iface, param = path:match('^rpc%.datausage%.interface%.@([^%.]+)%.(.*)$')
    assert(iface and response[iface], path)
    if param ~= '' then return {{value = taint(registered.get(nil,param,iface))}} end
    local rows = {}
    for key,value in pairs(registered.getall(nil,iface)) do
      rows[#rows+1] = {path='rpc.datausage.interface.@' .. iface .. '.',param=key,value=taint(value)}
    end
    return rows
  end,
  set = function(path, value)
    local iface=path:match('^rpc%.datausage%.interface%.@([^%.]+)%.reset$')
    assert(iface and value=='1')
    return registered.set(nil,'reset',value,iface)
  end,
} end
local f=assert(io.open(root .. '/usr/lib/lua/web/content_helper.lua','r'))
local source=f:read('*a'); f:close()
local start=assert(source:find('local function convertResultToObject(',1,true))
local finish=assert(source:find('\nend',start,true))+3
local convert=assert((loadstring or load)(source:sub(start,finish) .. '\nreturn convertResultToObject'))()
package.preload['web.content_helper'] = function() return {convertResultToObject=convert} end
package.preload.dkjson = function() return {encode = function(data, options)
  emitted=data; options.buffer[1]='encoded'; return true
end} end
gettext = {textdomain = function() end}
ngx = {HTTP_OK=200, header={}, req={get_post_args=function() return post end},
  say=function(value) output[#output+1]=type(value)=='table' and table.concat(value) or value end,
  print=function(value) output[#output+1]=string.untaint(value) end,
  exit=function(status) error({status=status}) end,
}
local endpoint=assert(loadfile(root .. '/www/docroot/ajax/datausage.lua'))
local function request(action, interface)
  read, write, output, emitted = {}, {}, {}, nil
  post={action=action,interface=interface}
  ngx.header={}
  local ok,err=pcall(endpoint)
  assert(not ok and type(err)=='table' and err.status==200, tostring(err))
  return table.concat(output)
end
response.wan={interface='wan',rx_bytes_total='4294967301',tx_bytes_total='9000000000',
  rx_bytes_average='512',tx_bytes_average='256',rx_bytes_per_second='1024',tx_bytes_per_second='2048',
  usage_limit_reached='false',usage_threshold_reached='true'}
response.smartphone={interface='smartphone',rx_bytes_total='9876543',tx_bytes_total='1234567'}
assert(type(taint('wan'))=='userdata')
request('get',taint('wan'))
assert(emitted and string.untaint(emitted.rx_bytes_total)=='4294967301')
assert(string.untaint(emitted.tx_bytes_total)=='9000000000')
assert(string.untaint(emitted.usage_threshold_reached)=='true')
assert(#read==1 and read[1]=='rpc.datausage.interface.@wan.' and #write==0)
assert(ngx.header.content_type=='application/json' and ngx.header['Cache-Control']=='no-store')
request(taint('get'),taint('wan'))
assert(emitted and string.untaint(emitted.rx_bytes_total)=='4294967301')
print('PASS protected HTTP arguments reach native counters, including totals above 32 bits')
request('get','smartphone')
assert(string.untaint(emitted.rx_bytes_total)=='9876543' and #read==1)
assert(#write==0)
print('PASS chosen logical interface is retained without guessing a physical device')
request(taint('reset'),taint('wan'))
assert(#write==1 and write[1]=='wan')
request('get','wan')
assert(string.untaint(emitted.rx_bytes_total)=='0' and string.untaint(emitted.tx_bytes_total)=='0')
assert(response.smartphone.rx_bytes_total=='9876543')
print('PASS reset uses the native reset method for only the selected interface')
assert(request(taint('overview'))=='1024,2048')
assert(ngx.header.content_type=='text/plain')
assert(#write==0)
print('PASS overview unwraps the selected interface and native rate values')
for _,value in ipairs({'../wan','wan;id','',{'wan','smartphone'},true,taint('../wan')}) do
  request('get',value)
  assert(#read==0 and #write==0 and not emitted)
  request('reset',value)
  assert(#read==0 and #write==0)
end
request('get',nil)
assert(#read==0 and #write==0)
request({'get','reset'},'wan')
assert(#read==0 and #write==0)
print('PASS malformed and repeated arguments cannot reach the datamodel')
available=false
assert(request(taint('get'),taint('wan'))=='{}' and not emitted)
assert(request(taint('overview'))=='0,0' and #write==0)
print('PASS unavailable native backend stays unavailable without fabricated counters')
for _,token in ipairs(handles) do if io.type(token)=='file' then token:close() end end
if not firmwareTaint then string.untaint=originalUntaint end
