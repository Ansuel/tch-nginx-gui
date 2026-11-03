local root,folder,case=arg[1],arg[2],arg[3]
local function copy(t) if type(t)~='table' then return t end local n={} for k,v in pairs(t) do n[k]=copy(v) end return n end
local function exec(s) local a,_,c=os.execute(s); return a==0 or a==true and (c==nil or c==0) end
local function encode(v)
    if type(v)=='table' then
        local keys={}; for k in pairs(v) do keys[#keys+1]=k end
        table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
        local p={}; for _,k in ipairs(keys) do p[#p+1]='['..encode(k)..']='..encode(v[k]) end
        return '{'..table.concat(p,',')..'}'
    end
    if type(v)=='string' then return string.format('%q',v) end
    return tostring(v)
end
package.preload.dkjson=function() return {encode=encode,decode=function(s) local f=(loadstring or load)('return '..s); return f and f() end} end
local M=assert(loadfile(root..'/decompressed/smartphone/usr/share/modgui-smartphone/uplink.lua'))()
if case=='health' then
    local h={wan={up=true,good=2,bad=0},phone={up=true,good=2,bad=0}}
    assert(M.choose('fallback',h)=='wan' and M.choose('primary',h)=='phone')
    for _=1,2 do h.wan=M.health(h.wan,false,true); assert(M.choose('fallback',h)=='wan') end
    h.wan=M.health(h.wan,false,true); assert(M.choose('fallback',h)=='phone')
    h.wan=M.health(h.wan,true,true); assert(M.choose('fallback',h)=='phone')
    h.wan=M.health(h.wan,true,true); assert(M.choose('fallback',h)=='wan')
    h.phone=M.health(h.phone,false,false); assert(M.choose('primary',h)=='wan')
    for _=1,2 do h.phone=M.health(h.phone,true,true) end
    assert(M.choose('primary',h)=='phone'); return
end
local db={network={wan={['.type']='interface',proto='dhcp',metric='7'}},
    firewall={wan={['.type']='zone',name='wan',masq='1',network={'wan','wan6'}}},
    dhcp={main={['.type']='dnsmasq',resolvfile=folder..'/original.resolv'}},smartphone={}}
local f=assert(io.open(folder..'/original.resolv','w')); f:write('nameserver 192.0.2.1\n'); f:close()
local u={}
function u:get_all(p,s) return copy(db[p] and db[p][s]) end
function u:get(p,s,o) local t=db[p] and db[p][s]; return t and copy(o and t[o] or t['.type']) end
function u:set(p,s,o,v)
    db[p]=db[p] or {}; db[p][s]=db[p][s] or {}
    if v==nil then db[p][s]['.type']=o else db[p][s][o]=copy(v) end
    return true
end
function u:delete(p,s,o) if db[p] then if o then if db[p][s] then db[p][s][o]=nil end else db[p][s]=nil end end return true end
function u:foreach(p,kind,fn) for name,t in pairs(db[p] or {}) do if t['.type']==kind then local x=copy(t); x['.name']=name; fn(x) end end return true end
function u:commit() return true end
function u:unload() return true end
local statuses={
    wan={up=true,l3_device='wan0',metric=7,['ipv4-address']={{address='192.0.2.2',mask=24}},
        route={{target='0.0.0.0',mask=0,nexthop='192.0.2.1'}},['dns-server']={'192.0.2.1'}},
    modgui_phone={up=true,l3_device='phone0',metric=1007,['ipv4-address']={{address='198.51.100.2',mask=24}},
        route={{target='0.0.0.0',mask=0,nexthop='198.51.100.1'}},['dns-server']={},inactive={['dns-server']={'198.51.100.1'}}}}
local bus={call=function(_,name)
    if name=='network.interface' then return {interface={{interface='wan',metric=7},{interface='modgui_phone',metric=1007}}} end
    return copy(statuses[name:match('network.interface.(.+)')])
end}
local commands,rules,routes={}, {}, {main='native default'}
local reachable={['192.0.2.2']=true,['198.51.100.2']=true}
local fail,pending,occupied=nil,false,false
local function key(a) local p={} for _,v in ipairs(a) do p[#p+1]=tostring(v) end return table.concat(p,' ') end
local env={uci=u,bus=bus,runtime=folder..'/runtime',config_path=folder..'/config',pid='12345',usb=function() return 'phone0' end}
env.run=function(a)
    local cmd=key(a); commands[#commands+1]=cmd
    if a[1]=='mkdir' and a[2]==folder..'/runtime/control.lock' then return exec('mkdir '..string.format('%q',a[2])..' 2>/dev/null') end
    if a[1]=='rmdir' then return exec('rmdir '..string.format('%q',a[2])..' 2>/dev/null') end
    if a[1]=='kill' then return a[3]~='888' end
    if cmd==fail then
        fail=nil
        if case=='concurrent' then
            db.network.other={['.type']='interface',proto='static'}
            db.firewall.wan.network[#db.firewall.wan.network+1]='other_network'
            db.dhcp.main.other_setting='preserve'
        end
        return false
    end
    if a[1]=='ping' then for i,v in ipairs(a) do if v=='-I' then return reachable[a[i+1]] end end end
    if a[1]=='ip' and a[3]=='rule' then
        if a[4]=='add' then rules[#rules+1]=cmd; return true end
        if a[4]=='del' then
            local pref,t
            for i,v in ipairs(a) do if v=='pref' then pref=tostring(a[i+1]) elseif v=='lookup' then t=tostring(a[i+1]) end end
            for i,r in ipairs(rules) do if r:find('pref '..pref..' ',1,true) and r:find('lookup '..t,1,true) then table.remove(rules,i); return true end end
            return false
        end
    end
    if a[1]=='ip' and a[3]=='route' then
        local t; for i,v in ipairs(a) do if v=='table' then t=tostring(a[i+1]) end end
        assert(t~='main' and t~='local','Native routes must not be changed')
        if a[4]=='flush' then routes[t]=nil else routes[t]=cmd end
    end
    return true
end
env.read=function(a)
    if a[1]=='uci' and a[2]=='changes' then return pending and a[3]=='network' and 'network.other=value' or '' end
    if a[1]=='uci' and a[2]=='export' then return encode(db[a[3]]) end
    if a[1]=='ip' and a[3]=='rule' then return occupied and '100: from all lookup custom\n' or '' end
    if a[1]=='ip' and a[3]=='route' then return '' end
    return ''
end
env.restore=function(name,body) db[name]=package.loaded.dkjson.decode(body) end
local app=M.new(env)
local function state()
    local s=assert(io.open(folder..'/runtime/status.json')):read('*a')
    return package.loaded.dkjson.decode(s)
end
local before=encode(db)
if case=='invalid' then
    assert(not pcall(app.apply,'fallback; reboot')); assert(#commands==0); assert(encode(db)==before)
elseif case=='conflict' then
    pending=true; assert(not pcall(app.apply,'fallback')); assert(encode(db)==before)
    pending=false; db.network.modgui_phone={['.type']='interface',proto='static'}
    local snapshot=encode(db); assert(not pcall(app.apply,'fallback')); assert(encode(db)==snapshot)
elseif case=='reserved' then
    occupied=true; assert(not pcall(app.apply,'fallback')); assert(encode(db)==before); assert(#commands==0)
elseif case=='rollback' then
    fail='/etc/init.d/firewall reload'; assert(not pcall(app.apply,'fallback')); assert(encode(db)==before)
elseif case=='concurrent' then
    fail='/etc/init.d/firewall reload'; assert(not pcall(app.apply,'fallback'))
    assert(db.network.other and not db.network.modgui_phone)
    assert(db.network.wan.metric=='7' and db.dhcp.main.other_setting=='preserve')
    assert(db.dhcp.main.resolvfile==folder..'/original.resolv')
    assert(table.concat(db.firewall.wan.network,',')=='wan,wan6,other_network')
elseif case=='lock' then
    assert(exec('mkdir '..string.format('%q',folder..'/runtime/control.lock')))
    local path=folder..'/runtime/control.lock/pid'
    local f=assert(io.open(path,'w')); f:write('777'); f:close()
    assert(not pcall(app.control,'fallback')); assert(encode(db)==before)
    assert(app.step()); assert(encode(db)==before)
    f=assert(io.open(path,'w')); f:write('888'); f:close()
    assert(app.control('fallback')); assert(db.smartphone.uplink.mode=='fallback')
    assert(app.control('stop')); assert(not db.network.modgui_phone)
elseif case=='apply' or case=='change' then
    assert(app.apply('fallback'))
    assert(db.network.modgui_phone.proto=='dhcp' and db.network.modgui_phone.ifname=='phone0')
    assert(db.network.wan.metric=='7' and db.smartphone.uplink.mode=='fallback')
    assert(db.dhcp.main.resolvfile==folder..'/runtime/resolv.conf')
    if case=='change' then
        assert(app.apply('primary')); assert(db.smartphone.uplink.mode=='primary')
        assert(db.network.modgui_phone.metric=='1007')
    end
    db.firewall.wan.network[#db.firewall.wan.network+1]='custom_other'
    assert(app.stop()); assert(not db.network.modgui_phone); assert(db.network.wan.metric=='7')
    assert(table.concat(db.firewall.wan.network,',')=='wan,wan6,custom_other')
    assert(db.dhcp.main.resolvfile==folder..'/original.resolv')
    assert(routes.main=='native default' and #rules==0)
elseif case=='monitor' or case=='unplug' then
    assert(app.apply(case=='unplug' and 'primary' or 'fallback'))
    assert(app.step()); assert(app.step())
    assert(state().active==(case=='unplug' and 'phone' or 'wan'))
    if case=='monitor' then
        reachable['192.0.2.2']=false
        app.step(); app.step(); assert(state().active=='wan')
        app.step(); assert(state().active=='phone'); assert(routes['29998']:find('phone0',1,true))
        local f=assert(io.open(folder..'/runtime/resolv.conf')); assert(f:read('*a'):find('198.51.100.1',1,true)); f:close()
        reachable['192.0.2.2']=true; app.step(); assert(state().active=='phone')
        app.step(); assert(state().active=='wan')
        f=assert(io.open(folder..'/runtime/resolv.conf')); assert(f:read('*a'):find('192.0.2.1',1,true)); f:close()
    else
        statuses.modgui_phone.up=false; app.step(); assert(state().active=='wan')
        statuses.modgui_phone.up=true; app.step(); app.step(); assert(state().active=='phone')
    end
    local joined=table.concat(commands,'\n')
    assert(joined:find('fwmark 0/0xffffffff lookup main suppress_prefixlength 0',1,true))
    assert(joined:find('from 198.51.100.2/32 to 1.1.1.1/32 lookup 29997',1,true))
    assert(routes.main=='native default')
    app.stop(); assert(#rules==0 and routes['29998']==nil)
else error(case) end
