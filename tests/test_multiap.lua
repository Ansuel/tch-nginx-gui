-- Exercise GUI RPC setters against the unmodified firmware credential router.
local root, nativePath = assert(arg[1]), assert(arg[2])
local db, pending, commits, events, registered = {}, {}, {}, {}, {}
local function section(config, name)
  return pending[config] and pending[config][name] or db[config][name]
end
local function copy(t)
  local out = {}
  for k,v in pairs(t) do out[k] = type(v) == 'table' and copy(v) or v end
  return out
end
local uci = {
  get_from_uci = function(b)
    local s = section(b.config, b.sectionname)
    return s and s[b.option] or ''
  end,
  set_on_uci = function(b, v)
    pending[b.config] = pending[b.config] or {}
    pending[b.config][b.sectionname] = pending[b.config][b.sectionname] or copy(db[b.config][b.sectionname])
    pending[b.config][b.sectionname][b.option] = v
    return true
  end,
  foreach_on_uci = function(b, callback)
    for name,s in pairs(db[b.config]) do
      if s['.type'] == (b.sectiontype or b.sectionname) then
        callback(section(b.config, name))
      end
    end
  end,
  commit = function(b)
    commits[b.config] = (commits[b.config] or 0) + 1
    for name,s in pairs(pending[b.config] or {}) do db[b.config][name] = s end
    pending[b.config] = nil
    return true
  end,
  revert = function(b) pending[b.config] = nil end,
}
lfs = {attributes = function() return 'file' end}
package.preload['transformer.mapper.ucihelper'] = function() return uci end
package.preload['ubus'] = function() return {connect = function() return {
  call = function() return {} end,
  send = function(_, name) events[#events+1] = name end,
} end} end
package.preload['transformer.shared.common.network'] = function() return {} end
package.preload['transformer.shared.bandsteerhelper'] = function() return assert(loadfile(nativePath))() end
package.preload.modgui = function() return {getRightLoggerModule = function() return {
  new = function() return {error = function() end} end,
} end} end
mapper = function(name)
  if name == 'ucihelper' then return uci end
  if name == 'ubus' then return require('ubus') end
  if name == 'nwcommon' then return {} end
  error(name)
end
commitapply = {newset = function() end}
register = function(m) registered[m.objectType.name] = m end
assert(loadfile(root .. '/usr/share/transformer/mappings/rpc/wireless.ssid.map'))()
assert(loadfile(root .. '/usr/share/transformer/mappings/rpc/wireless.ap.security.map'))()
local ssid = registered['rpc.wireless.ssid.@.']
local security = registered['rpc.wireless.ap.@.security.']
local function reset()
  db = {
    multiap = {
      controller = {enabled='1', supported_security_modes='none wpa2-psk'},
      agent = {enabled='1'}, tch_feature_extensions = {enable='0'},
      cred7 = {['.name']='cred7', ['.type']='controller_credentials', fronthaul='1',
        backhaul='0', frequency_bands='radio_2G', ssid='saved24', wpa_psk_key='saved-passphrase', state='1'},
      cred9 = {['.name']='cred9', ['.type']='controller_credentials', fronthaul='1',
        backhaul='0', frequency_bands='radio_5Gl,radio_5Gu', ssid='saved5', wpa_psk_key='saved-passphrase', state='1'},
    },
    wireless = {
      wl0={ssid='runtime24'}, wl1={ssid='runtime5'}, wl0_1={ssid='guest'},
      ap0={iface='wl0'}, ap1={iface='wl1'}, ap2={iface='wl0_1'},
    },
    web = {main={['.type']='network', cred={'cred7','cred9'}, intf={'wl0','wl1'}, splitssid='1'},
      guest={['.type']='network', cred={'cred3','cred4'}, intf={'wl0_1','wl1_1'}}}, system = {},
  }
  pending, commits, events = {}, {}, {}
  ssid.revert(); security.revert()
  package.loaded['transformer.shared.bandsteerhelper'] = nil
end
reset()
assert(ssid.set.ssid(nil,'ssid','Renamed 5GHz','wl1'))
assert(not pending.wireless and section('multiap','cred9').ssid=='Renamed 5GHz')
ssid.commit()
assert(db.multiap.cred9.ssid=='Renamed 5GHz' and db.multiap.cred7.ssid=='saved24')
assert(commits.multiap==1 and #events==0)
assert(security.set(nil,'wpa_psk_passphrase','New test password','ap1'))
security.commit()
assert(db.multiap.cred9.wpa_psk_key=='New test password')
assert(security.set(nil,'mode','none','ap1'))
security.commit()
assert(db.multiap.cred9.security_mode=='none')
assert(not security.set(nil,'wpa_psk_passphrase','short','ap1'))
print('PASS split profiles: SSID, key, security, validation and persistent commit')
reset()
assert(ssid.set.ssid(nil,'ssid','Discarded','wl0'))
ssid.revert()
assert(not pending.multiap and db.multiap.cred7.ssid=='saved24')
assert(security.set(nil,'wpa_psk_passphrase','Discarded test key','ap0'))
security.revert()
assert(not pending.multiap and db.multiap.cred7.wpa_psk_key=='saved-passphrase')
print('PASS failed transactions revert controller credentials')
reset()
db.multiap.cred7.frequency_bands='radio_2G,radio_5Gl,radio_5Gu'
db.multiap.cred9.state='0'
assert(ssid.set.ssid(nil,'ssid','United name','wl0'))
ssid.commit()
assert(db.multiap.cred7.ssid=='United name' and db.multiap.cred9.ssid=='United name')
assert(db.multiap.cred9.state=='0')
print('PASS combined bands follow the native helper without enabling a split profile')
reset()
db.multiap.cred9.state='0'
assert(ssid.set.ssid(nil,'ssid','Configured while disabled','wl1'))
ssid.commit()
assert(db.multiap.cred9.ssid=='Configured while disabled' and db.multiap.cred9.state=='0')
print('PASS inactive split credentials can be configured without being enabled')
reset()
db.multiap.cred9.backhaul='1'
assert(not ssid.set.ssid(nil,'ssid','Protected','wl1'))
assert(not security.set(nil,'wpa_psk_passphrase','Protected test key','ap1'))
assert(not pending.multiap and not pending.wireless)
print('PASS backhaul credentials protected')
reset()
db.multiap.tch_feature_extensions.enable='1'
db.multiap.cred3={['.name']='cred3', ['.type']='controller_credentials',
  fronthaul='1',backhaul='0',frequency_bands='radio_2G',ssid='guest',state='0'}
db.multiap.cred4={['.name']='cred4', ['.type']='controller_credentials',
  fronthaul='1',backhaul='0',frequency_bands='radio_5Gl,radio_5Gu',ssid='guest5',state='0'}
assert(ssid.set.ssid(nil,'ssid','Managed guest','wl0_1'))
ssid.commit()
assert(db.multiap.cred3.ssid=='Managed guest' and db.wireless.wl0_1.ssid=='guest')
print('PASS guest credentials follow the firmware feature flag')
reset()
db.web={}
local ok,err = ssid.set.ssid(nil,'ssid','Missing associations','wl0')
assert(not ok and err and not pending.wireless and not pending.multiap)
print('PASS missing metadata fails without creating divergent wireless state')
reset()
ssid.set.ssid(nil,'ssid','New guest','wl0_1'); ssid.commit()
assert(db.wireless.wl0_1.ssid=='New guest' and not commits.multiap)
for _, states in ipairs({{'0','0'}, {'0','1'}, {'1','0'}}) do
  reset(); db.multiap.controller.enabled=states[1]; db.multiap.agent.enabled=states[2]
  ssid.set.ssid(nil,'ssid','Local name','wl1'); ssid.commit()
  assert(db.wireless.wl1.ssid=='Local name' and not commits.multiap)
end
reset(); db.multiap={}
ssid.set.ssid(nil,'ssid','Legacy name','wl0'); ssid.commit()
assert(db.wireless.wl0.ssid=='Legacy name')
print('PASS unmanaged guests, agent-only, disabled mesh and legacy firmware')
reset()
package.loaded['transformer.shared.bandsteerhelper'] = nil
package.preload['transformer.shared.bandsteerhelper'] = function() error('missing native module') end
local ok,err = ssid.set.ssid(nil,'ssid','Must not diverge','wl0')
assert(not ok and err and not pending.wireless)
package.loaded['transformer.shared.bandsteerhelper'] = {
  isMultiapEnabled = function() return true end,
  setSecurityOption = function() error('must not substitute for missing SSID setter') end,
}
local ok,err = ssid.set.ssid(nil,'ssid','Missing setter','wl0')
assert(not ok and err and not pending.wireless)
print('PASS active mesh fails explicitly when native support is unavailable')
