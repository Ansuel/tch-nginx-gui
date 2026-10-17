-- Optional LuCI extension: native Quantenna RPC, independent of LuCI libraries.
local M = {}
local fs = require('nixio.fs')
local uci = require('uci')
local config = 'luci_qtn'
local function cursor() return uci.cursor() end
local function shellquote(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end
local function remotequote(s)
  assert(tostring(s):match('^[%w_.:/%-]+$'),'Unsupported remote token')
  return tostring(s)
end
function M.available()
  return fs.access('/usr/sbin/qtn_call_qcsapi.sh') and (fs.access('/usr/bin/timeout') or fs.access('/bin/timeout'))
end
-- QCSAPI takes a command string; quote both the local shell and remote tokens.
-- Never return command text on error: it may contain a key.
local function rpc_command(payload)
  -- Replace the wrapper shell with its RPC child so timeout also closes the
  -- child's output pipe; killing only the wrapper can leave read('*a') blocked.
  local launcher='qtn_qcsapi_eth() { exec qtn_qcsapi_eth "$@"; }; . /usr/sbin/qtn_call_qcsapi.sh'
  return 'timeout 8 /bin/sh -c '..shellquote(launcher)..' qtn-rpc '..shellquote(payload)
end
local function rpc(command, ...)
  local args = {command}
  for _, v in ipairs({...}) do args[#args+1] = remotequote(v) end
  local p = io.popen(rpc_command(table.concat(args,' ')) .. ' 2>/dev/null')
  if not p then return nil end
  local value = p:read('*a'); p:close()
  value = value and value:gsub('[\r\n]+$', '')
  if not value or value == '' or value:match('^QCS API error') or value:find('not found',1,true) or value:find('Too few',1,true) then return nil end
  return value
end
-- Vendor CLI output can contain unrelated asynchronous notifications instead of
-- "complete". Only read-back of the requested state establishes success.
local function confirmed(command,args,getter,getargs,expected,deadline)
  for attempt=1,3 do
    if deadline and os.time()>deadline then break end
    rpc(command,unpack(args))
    for poll=1,4 do
      require('nixio').nanosleep(1)
      if deadline and os.time()>deadline then break end
      local value=rpc(getter,unpack(getargs))
      if type(expected)=='function' and expected(value) or value==expected then return true end
    end
  end
  error({stage=command},0)
end
local function stage_error(err)
  return type(err)=='table' and err.stage and (' ('..err.stage..')') or ''
end
local function checked(...)
  local result=rpc(...)
  if not (result and result:find('complete',1,true)) then error({stage=select(1,...)},0) end
end
local function remote(id) return type(id)=='string' and (id:match('^qtn_(wifi[23])$') or id:match('^(wifi[23])$')) end
local function status(id) return rpc('get_status',id) end
function M.list()
  local c, result = cursor(), {}
  c:foreach(config,'network',function(s)
    if remote(s['.name']) and s.managed=='1' then result[#result+1]=s end
  end)
  table.sort(result,function(a,b) return a['.name']<b['.name'] end)
  return result
end
function M.primary_network()
  return cursor():get('wireless','wl1','network')
end
local function validate(s)
  assert(type(s.ssid)=='string' and #s.ssid>0 and #s.ssid<=32 and not s.ssid:find('[%z\1-\31\127]'), 'Invalid SSID')
  assert(s.ssid:match('^[%w_.%-]+$'),'Remote SSID must use letters, numbers, dot, underscore or hyphen')
  assert(type(s.password)=='string' and ((#s.password>=8 and #s.password<=63 and s.password:match('^[ -~]+$')) or (#s.password==64 and s.password:match('^%x+$'))), 'Invalid key')
  assert(s.enabled=='0' or s.enabled=='1','Invalid state')
  assert(s.network==M.primary_network() and s.network~=nil,'The remote SSID must use the primary radio network')
end
local function prepare(s)
  local crypto=require('modgui.wpa_psk')
  local fingerprint=crypto.fingerprint(s.ssid,s.password)
  if s.keyid~=fingerprint or not s.psk then
    s.psk=crypto.derive(s.ssid,s.password); s.keyid=fingerprint
    return true
  end
end
local function ensure_file()
  if not fs.access('/etc/config/'..config) then local f=assert(io.open('/etc/config/'..config,'w')); f:close() end
  assert(fs.chmod('/etc/config/'..config,'600'))
end
local function write(id,s)
  ensure_file()
  local c=cursor(); assert(c:load(config))
  if not c:get(config,id) then assert(c:set(config,id,'network')) end
  for _,k in ipairs({'ssid','password','psk','keyid','enabled','network','managed'}) do assert(c:set(config,id,k,s[k])) end
  assert(c:commit(config)); assert(fs.chmod('/etc/config/'..config,'600'))
end
local function guarded(fn)
  local path='/var/run/modgui-luci-qtn.lock'
  if not fs.mkdir(path) then
    local f=io.open(path..'/pid'); local pid=f and tonumber(f:read('*l')); if f then f:close() end
    if pid and not require('nixio').kill(pid,0) then os.remove(path..'/pid'); fs.rmdir(path) end
    local modified=fs.stat(path,'mtime')
    if not pid and modified and os.time()-modified>30 then fs.rmdir(path) end
    if not fs.mkdir(path) then return nil,'Quantenna is busy; retry shortly' end
  end
  local f=assert(io.open(path..'/pid','w')); f:write(require('nixio').getpid()); f:close()
  local ok,a,b=pcall(fn)
  os.remove(path..'/pid'); fs.rmdir(path)
  if not ok then return nil,'Could not configure Quantenna; check radio availability' end
  return a,b
end
local function configure(id,s)
  validate(s)
  prepare(s)
  assert(status('wifi0'),'Quantenna is not ready')
  local exists=status(id)
  local restore_rf=cursor():get('wireless','radio_5G','state')=='1' and '1' or '0'
  local paused, guard_pid=false,nil
  local deadline=os.time()+90
  if not exists then
    -- Keep the watchdog independent of the LuCI request process.
    local guard='(sleep 180; '..rpc_command('wifi_remove_bss '..id)..' >/dev/null 2>&1; '..
      rpc_command('rfenable '..restore_rf)..' >/dev/null 2>&1; /etc/init.d/hostapd reload >/dev/null 2>&1) >/dev/null 2>&1 & echo $!'
    local p=assert(io.popen(guard)); guard_pid=tonumber(p:read('*l')); p:close(); assert(guard_pid)
  end
  local function set(command,getter,value,index)
    local args=index and {id,index,value} or {id,value}
    confirmed(command,args,getter,index and {id,index} or {id},value,deadline)
  end
  local function enable(value)
    confirmed('enable_interface',{id,value},'get_status',{id},value=='1' and 'Up' or 'Disabled',deadline)
  end
  local ok,failure=pcall(function()
    if not exists then
      paused=true -- Restore RF even when the pause command's acknowledgement is lost.
      confirmed('rfenable',{'0'},'rfstatus',{},'Off',deadline)
      confirmed('wifi_create_bss',{id},'get_status',{id},function(v) return v=='Up' or v=='Disabled' end,deadline)
    end
    enable('0')
    set('set_SSID','get_SSID',s.ssid)
    set('set_beacon','get_beacon','11i')
    set('set_WPA_authentication_mode','get_WPA_authentication_mode','PSKAuthentication')
    set('set_WPA_encryption_modes','get_WPA_encryption_modes','AESEncryption')
    set('set_pre_shared_key','get_pre_shared_key',s.psk,'0')
  end)
  if not ok then
    if not exists then rpc('wifi_remove_bss',id) else rpc('enable_interface',id,'0') end
  end
  if paused then
    restore_rf=cursor():get('wireless','radio_5G','state')=='1' and '1' or '0'
    -- A failed new BSS must be absent before RF can be restored.
    if not ok and status(id) then error(failure,0) end
    local restored,restore_error=pcall(confirmed,'rfenable',{restore_rf},'rfstatus',{},restore_rf=='1' and 'On' or 'Off')
    os.execute('timeout 20 /etc/init.d/hostapd reload >/dev/null 2>&1')
    if restored and guard_pid then require('nixio').kill(guard_pid,15) end
    if not restored then error(restore_error,0) end
  end
  if not ok then error(failure,0) end
  local final=s.enabled=='1' and restore_rf or '0'
  confirmed('enable_interface',{id,final},'get_status',{id},final=='1' and 'Up' or 'Disabled',os.time()+20)
end
function M.create(data)
  return guarded(function()
    local s={ssid=data.ssid,password=data.password,network=data.network,enabled=data.enabled,managed='1'}
    validate(s)
    local c,id=cursor(),nil
    for i=2,3 do local candidate='wifi'..i; if not c:get(config,candidate) and not status(candidate) then id=candidate; break end end
    assert(id,'No free remote BSS slot')
    local ok,err=pcall(configure,id,s)
    if not ok then rpc('wifi_remove_bss',id); return nil,'Could not create secured 5 GHz network'..stage_error(err) end
    local saved=pcall(write,id,s)
    if not saved then rpc('wifi_remove_bss',id); return nil,'Could not persist 5 GHz network' end
    return 'qtn_'..id
  end)
end
-- The request must finish before RF is paused: a Wi-Fi client may lose its
-- HTTP connection during provisioning. Job files never leave this private dir.
local jobdir='/var/run/modgui-luci-qtn-jobs'
local jobfields={'ssid','password','network','enabled','state','id','message','started'}
local function jobpath(token)
  assert(type(token)=='string' and #token==32 and token:match('^%x+$'),'Invalid job')
  return jobdir..'/'..token
end
local function write_job(token,data)
  fs.mkdir(jobdir); assert(fs.chmod(jobdir,'700'))
  local path=jobpath(token)
  local f=assert(io.open(path..'.new','w')); assert(fs.chmod(path..'.new','600'))
  for _,key in ipairs(jobfields) do
    if data[key] then
      local value=tostring(data[key]):gsub('.',function(c) return string.format('%02x',c:byte()) end)
      assert(f:write(key..'='..value..'\n'))
    end
  end
  assert(f:close()); assert(os.rename(path..'.new',path))
end
local function read_job(token)
  local f=io.open(jobpath(token)); if not f then return nil end
  local text=f:read(8192); f:close(); local data={}
  for key,value in (text or ''):gmatch('(%w+)=(%x*)\n') do
    data[key]=value:gsub('%x%x',function(h) return string.char(tonumber(h,16)) end)
  end
  return data
end
function M.start_job(data)
  validate(data)
  local f=assert(io.open('/proc/sys/kernel/random/uuid')); local token=f:read('*l'):gsub('-',''); f:close()
  write_job(token,{ssid=data.ssid,password=data.password,network=data.network,enabled=data.enabled,state='pending',started=tostring(os.time())})
  local result=os.execute('start-stop-daemon -S -b -m -p '..jobpath(token)..'.pid -x /usr/bin/lua -- /usr/share/modgui-luci-wireless/qtn-worker.lua job '..token..' >/dev/null 2>&1')
  if result~=0 and result~=true then os.remove(jobpath(token)); return nil,'Could not start 5 GHz provisioning' end
  return token,nil,'pending'
end
function M.run_job(token)
  local data=assert(read_job(token)); assert(data.state=='pending')
  -- Remove credentials from disk before starting the operation.
  write_job(token,{state='running',started=data.started})
  local ok,id,message
  for attempt=1,10 do
    ok,id,message=pcall(M.create,data)
    if not ok or id or message~='Quantenna is busy; retry shortly' then break end
    require('nixio').nanosleep(1)
  end
  write_job(token,ok and id and {state='done',id=id} or
    {state='failed',message=ok and message or 'Could not provision 5 GHz network'})
  os.remove(jobpath(token)..'.pid')
end
function M.job_status(token)
  local ok,data=pcall(read_job,token)
  if not ok or not data then return {state='failed',message='Provisioning job unavailable'} end
  if (data.state=='pending' or data.state=='running') and data.started and os.time()-tonumber(data.started)>180 then
    return {state='failed',message='Provisioning was interrupted; check the wireless overview before retrying'}
  end
  return {state=data.state,id=data.id,message=data.message}
end
function M.password(id)
  id=remote(id); return id and cursor():get(config,id,'password') or nil
end
function M.update(id,data)
  id=remote(id); if not id then return nil,'Invalid network' end
  return guarded(function()
    local old=cursor():get_all(config,id); assert(old and old.managed=='1')
    local s={ssid=data.ssid or old.ssid,password=data.password and data.password~='' and data.password or old.password,
      enabled=data.enabled or old.enabled,network=old.network,managed='1',psk=old.psk,keyid=old.keyid}
    validate(s)
    if s.ssid==old.ssid and s.password==old.password and s.enabled==old.enabled then return true,'No changes to apply' end
    if not pcall(configure,id,s) then pcall(configure,id,old); return nil,'Could not apply remote settings; previous configuration retained' end
    if not pcall(write,id,s) then pcall(configure,id,old); return nil,'Could not save remote settings' end
    return true,'Changes applied successfully'
  end)
end
function M.remove(id)
  id=remote(id); if not id then return nil,'Invalid network' end
  return guarded(function()
    local c=cursor(); assert(c:get(config,id,'managed')=='1')
    assert(status('wifi0'))
    if status(id) then checked('wifi_remove_bss',id) end
    assert(c:delete(config,id)); assert(c:commit(config))
    return true
  end)
end
function M.networks()
  local result={}
  for _,s in ipairs(M.list()) do
    local id=s['.name']; local state=status(id)
    local n={id='qtn_'..id,ap='qtn_'..id,qtn=true,owned=true,editable=true,ssid=s.ssid,network=s.network,
      enabled=s.enabled,up=state=='Up',security='wpa2-psk',stations={},station_error=not state and 'Remote radio unavailable' or nil}
    local count=state and tonumber(rpc('get_count_associations',id)) or 0
    for i=0,math.min(count or 0,16)-1 do
      local mac=rpc('get_associated_device_mac_addr',id,tostring(i))
      if mac and mac:match('^%x%x:%x%x:%x%x:%x%x:%x%x:%x%x$') then
        local rx=tonumber(rpc('get_rx_phy_rate_per_association',id,tostring(i)))
        local tx=tonumber(rpc('get_tx_phy_rate_per_association',id,tostring(i)))
        n.stations[#n.stations+1]={mac=mac,signal=tonumber(rpc('get_rssi_in_dbm_per_association',id,tostring(i))),rx=rx and rx*1000,tx=tx and tx*1000}
      end
    end
    result[#result+1]=n
  end
  return result
end
function M.reconcile()
  return guarded(function()
    for _,s in ipairs(M.list()) do
      local id=s['.name']
      local changed=prepare(s)
      local state=status(id)
      if not state then configure(id,s); if changed then write(id,s) end
      else
        local key=rpc('get_pre_shared_key',id,'0')
        if changed or rpc('get_SSID',id)~=s.ssid or rpc('get_beacon',id)~='11i' or key~=s.psk then configure(id,s); if changed then write(id,s) end end
        local expected=cursor():get('wireless','radio_5G','state')=='1' and s.enabled=='1'
        if (state=='Up')~=expected then
          confirmed('enable_interface',{id,expected and '1' or '0'},'get_status',{id},expected and 'Up' or 'Disabled',os.time()+30)
        end
      end
    end
    return true
  end)
end
return M
