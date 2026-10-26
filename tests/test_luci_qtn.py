from pathlib import Path
import hashlib
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / 'decompressed/luci_wireless/usr/lib/lua/modgui/luci_qtn.lua'
CRYPTO = ROOT / 'decompressed/luci_wireless/usr/lib/lua/modgui/wpa_psk.lua'
BIT_SHIM = r'''
unpack = unpack or table.unpack
if not pcall(require, 'bit') then
  package.preload.bit = function()
    return assert(load([[
      local mask=0xffffffff
      local function fold(op,...)
        local a={...}; local v=a[1]&mask
        for i=2,#a do if op=='and' then v=v&a[i] elseif op=='xor' then v=v~a[i] end end
        return v&mask
      end
      return {
        band=function(...) return fold('and',...) end,
        bxor=function(...) return fold('xor',...) end,
        bnot=function(a) return (~a)&mask end,
        rshift=function(a,n) return (a&mask)>>n end,
        rol=function(a,n) a=a&mask; return ((a<<n)|(a>>(32-n)))&mask end,
        tobit=function(a) a=a&mask; return a>=0x80000000 and a-0x100000000 or a end
      }
    ]]))()
  end
end
'''
FIXTURE = r'''
unpack = unpack or table.unpack
local configs={wireless={wl1={network='lan'},radio_5G={state='1'}},luci_qtn={}}
local rt={wifi0={ssid='Original',up=true},wifi1={ssid='Guest',up=false}}
local calls,commands={},{}
local fail,locked,mode=nil,false,nil
local rf,notification,drop_once='On',nil,nil
local c={}
function c:load() return true end
function c:get(cfg,id,k) local s=(configs[cfg] or {})[id]; return s and (k and s[k] or s['.type']) end
function c:get_all(cfg,id) return (configs[cfg] or {})[id] end
function c:foreach(cfg,kind,fn)
  for id,s in pairs(configs[cfg] or {}) do if s['.type']==kind then fn(s) end end
end
function c:set(cfg,id,k,v)
  if v==nil and (configs[cfg] or {})[id] then error('Existing section type cannot be reset') end
  configs[cfg]=configs[cfg] or {}; local s=configs[cfg][id] or {}; configs[cfg][id]=s
  s['.name']=id
  if v==nil then s['.type']=k else s[k]=v end
  return true
end
function c:commit() return true end
function c:delete(cfg,id) configs[cfg][id]=nil; return true end
package.loaded.uci={cursor=function() return c end}
package.loaded['nixio.fs']={
 access=function() return true end,
 chmod=function(_,m) mode=m; return true end,
 mkdir=function() if locked then return false end; locked=true; return true end,
 rmdir=function() locked=false; return true end,
 stat=function() return os.time() end
}
package.loaded.nixio={getpid=function() return 1234 end,kill=function() return true end,nanosleep=function() end}
package.loaded['modgui.wpa_psk']={
 fingerprint=function(s,p) return s..p end,
 derive=function() return string.rep('a',64) end
}
io.open=function() return {read=function() return '1234' end,write=function() return true end,close=function() return true end} end
os.remove=function() return true end
os.execute=function(cmd) commands[#commands+1]=cmd; return 0 end
io.popen=function(cmd)
 commands[#commands+1]=cmd
 local result
 if cmd:sub(1,1)=='(' then result='999' else
   local payload=assert(cmd:match("qtn%-rpc '([^']*)'"),cmd)
   local a={}; for t in payload:gmatch('%S+') do a[#a+1]=t end
   local op,id=a[1],a[2]; calls[#calls+1]=op..':'..tostring(id)
   if op==fail then result='QCS API error 22: failure'
   elseif op=='get_status' then result=rt[id] and (rt[id].up and 'Up' or 'Disabled') or 'QCS API error 19: missing'
   elseif op=='wifi_create_bss' then rt[id]={up=true,ssid='Default'}; result='complete'
   elseif op=='wifi_remove_bss' then rt[id]=nil; result='complete'
   elseif op=='rfenable' then rf=a[2]=='1' and 'On' or 'Off'; result='complete'
   elseif op=='rfstatus' then result=rf
   elseif op=='enable_interface' then rt[id].up=a[3]=='1'; result='complete'
   elseif op=='set_SSID' then rt[id].ssid=a[3]; result='complete'
   elseif op=='get_SSID' then result=rt[id].ssid
   elseif op=='set_beacon' then rt[id].beacon=a[3]; result='complete'
   elseif op=='get_beacon' then result=rt[id].beacon
   elseif op=='set_WPA_authentication_mode' then rt[id].auth=a[3]; result='complete'
   elseif op=='get_WPA_authentication_mode' then result=rt[id].auth
   elseif op=='set_WPA_encryption_modes' then rt[id].encryption=a[3]; result='complete'
   elseif op=='get_WPA_encryption_modes' then result=rt[id].encryption
   elseif op=='set_pre_shared_key' then rt[id].psk=a[4]; result='complete'
   elseif op=='get_pre_shared_key' then result=rt[id].psk
   elseif op=='get_count_associations' then result='0'
   else result='complete' end
   if op==notification then result='group assoc_limit 99' end
   if op==drop_once then result=nil; drop_once=nil end
 end
 return {read=function() return result end,close=function() return true end}
end
local q=dofile(MODULE)
local data={ssid='New-5G',password='Fixture with spaces $ and symbols!',network='lan',enabled='0'}
'''


@unittest.skipUnless(shutil.which('lua'), 'Lua runtime required')
class Quantenna(unittest.TestCase):
    def run_lua(self, code, fixture=True):
        source = 'local MODULE=' + repr(str(MODULE)) + '\n'
        source += FIXTURE if fixture else BIT_SHIM
        result = subprocess.run(['lua','-'], input=source+code, text=True,
                                capture_output=True, timeout=60)
        self.assertEqual(result.returncode,0,result.stderr)
        return result.stdout.strip()

    def test_wpa_vectors_and_hex_psk(self):
        for ssid,password in [('IEEE','password'),('Home-5G','A key with spaces $`!')]:
            expected=hashlib.pbkdf2_hmac('sha1',password.encode(),ssid.encode(),4096,32).hex()
            code='local w=dofile('+repr(str(CRYPTO))+')\nprint(w.derive('+repr(ssid)+','+repr(password)+'))'
            self.assertEqual(self.run_lua(code,False),expected)
        self.assertEqual(self.run_lua('local w=dofile('+repr(str(CRYPTO))+'); print(w.derive("SSID",string.rep("A",64)))',False),'a'*64)

    def test_create_secures_before_enable_and_keeps_keys_private(self):
        self.run_lua(r'''
assert(q.create(data)=='qtn_wifi2')
assert(mode=='600' and configs.luci_qtn.wifi2.password==data.password)
assert(not rt.wifi2.up and rt.wifi2.psk==string.rep('a',64))
local transcript=table.concat(commands,'\n')
assert(not transcript:find(data.password,1,true))
assert(transcript:find('wifi_remove_bss wifi2',1,true)) -- watchdog
local joined=table.concat(calls,',')
assert(joined:find('set_pre_shared_key:wifi2',1,true) < joined:find('get_pre_shared_key:wifi2',1,true))
local n=q.networks()[1]; assert(n.owned and n.id=='qtn_wifi2' and not n.password and not n.psk)
assert(q.password('qtn_wifi2')==data.password)
assert(rt.wifi0.ssid=='Original' and not rt.wifi1.up)
''')

    def test_failures_remove_new_bss_restore_rf_and_release_lock(self):
        self.run_lua(r'''
fail='set_pre_shared_key'
local id,message=q.create(data)
assert(not id and not rt.wifi2 and not configs.luci_qtn.wifi2)
assert(not locked and not message:find(data.password,1,true))
assert(table.concat(calls,','):find('rfenable:1',1,true))
''')

    def test_vendor_notifications_and_lost_ack_use_readback(self):
        self.run_lua(r'''
notification='set_SSID'
drop_once='rfenable'
assert(q.create(data)=='qtn_wifi2')
assert(rt.wifi2.ssid==data.ssid and rf=='On')
assert(rt.wifi2.auth=='PSKAuthentication' and rt.wifi2.encryption=='AESEncryption')
assert(table.concat(commands,'\n'):find('exec qtn_qcsapi_eth',1,true))
''')

    def test_failed_rf_pause_restores_radio_and_reports_stage(self):
        self.run_lua(r'''
fail='rfenable'
local id,message=q.create(data)
assert(not id and message:find('(rfenable)',1,true))
assert(not locked and not rt.wifi2)
assert(table.concat(calls,','):find('rfenable:1',1,true))
''')

    def test_background_job_keeps_credentials_private_and_reports_result(self):
        self.run_lua(r'''
local files={['/proc/sys/kernel/random/uuid']='12345678-1234-1234-1234-123456789abc'}
io.open=function(path,mode)
 if mode=='w' then files[path]='' elseif not files[path] then return nil end
 return {write=function(_,s) files[path]=files[path]..s; return true end,
 read=function(_,kind) return kind=='*l' and files[path]:match('[^\n]+') or files[path] end,
 close=function() return true end}
end
os.rename=function(a,b) files[b]=files[a]; files[a]=nil; return true end
os.remove=function(p) files[p]=nil; return true end
local mkdir=package.loaded['nixio.fs'].mkdir
package.loaded['nixio.fs'].mkdir=function(path) if path:find('qtn%-jobs') then return true end; return mkdir(path) end
local token,_,pending=q.start_job(data)
assert(#token==32 and pending=='pending' and q.job_status(token).state=='pending')
assert(not q.job_status(token).password)
assert(table.concat(commands,'\n'):find('start%-stop%-daemon'))
q.run_job(token)
local status=q.job_status(token)
assert(status.state=='done' and status.id=='qtn_wifi2' and not status.password)
local path='/var/run/modgui-luci-qtn-jobs/'..token
assert(not files[path]:find('password=',1,true))
assert(q.job_status('../invalid').state=='failed')
''')

    def test_reconcile_recreates_and_remove_preserves_native_networks(self):
        self.run_lua(r'''
assert(q.create(data)=='qtn_wifi2')
assert(q.update('qtn_wifi2',{enabled='1'}))
assert(rt.wifi2.up)
rt.wifi2=nil
assert(q.reconcile()); assert(rt.wifi2.up)
assert(q.remove('qtn_wifi2')); assert(not rt.wifi2 and not configs.luci_qtn.wifi2)
assert(not q.remove('wifi0') and rt.wifi0 and rt.wifi1)
''')

    def test_unmanaged_slots_and_invalid_input_are_preserved(self):
        self.run_lua(r'''
rt.wifi2={ssid='Unmanaged',up=true}
assert(q.create(data)=='qtn_wifi3')
assert(rt.wifi2.ssid=='Unmanaged')
local count=#commands
local bad={ssid='Invalid remote SSID',password=data.password,network='lan',enabled='1'}
assert(not q.create(bad)); assert(#commands==count)
locked=true
assert(not q.update('qtn_wifi3',{enabled='1'}))
''')

if __name__=='__main__':
    unittest.main()
