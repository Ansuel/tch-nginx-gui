-- IPv4 USB uplink management. netifd owns DHCP; this service owns only its
-- interface, WAN-zone membership, resolver file and reserved routing rules.
local json = require('dkjson')
local M = {}
local IFACE, OWNER = 'modgui_phone', 'smartphone-usb'
local TABLES = {wan = 29996, phone = 29997, active = 29998}
local TARGETS = {'1.1.1.1', '9.9.9.9'}
local function quote(v) return "'" .. tostring(v):gsub("'", "'\\''") .. "'" end
local function argv(args)
    local out = {}; for _, v in ipairs(args) do out[#out + 1] = quote(v) end
    return table.concat(out, ' ')
end
local function safe(v) return type(v) == 'string' and v:match('^[%w_.%-]+$') ~= nil end
local function ipv4(v)
    if type(v) ~= 'string' then return false end
    local a,b,c,d = v:match('^(%d+)%.(%d+)%.(%d+)%.(%d+)$')
    return a and tonumber(a)<256 and tonumber(b)<256 and tonumber(c)<256 and tonumber(d)<256
end
local function words(v)
    if type(v) == 'table' then return v end
    local t = {}; for s in tostring(v or ''):gmatch('%S+') do t[#t+1] = s end; return t
end
local function contains(t, value) for _, v in ipairs(words(t)) do if v == value then return true end end; return false end

-- Three failed checks withdraw a line; two successful checks restore it.
function M.health(previous, reachable, available)
    local h = previous or {up=false, good=0, bad=0}
    if not available then return {up=false, good=0, bad=3} end
    if reachable then h.good=h.good+1; h.bad=0; if h.good>=2 then h.up=true end
    else h.bad=h.bad+1; h.good=0; if h.bad>=3 then h.up=false end end
    return h
end
function M.choose(mode, health)
    local first = mode == 'primary' and 'phone' or 'wan'
    local second = first == 'phone' and 'wan' or 'phone'
    if health[first].up then return first end
    if health[second].up then return second end
    return 'none'
end

function M.new(env)
    env = env or {}
    local uci = env.uci or require('uci').cursor()
    local bus = env.bus or require('ubus').connect()
    local run = env.run or function(args)
        local a,_,c = os.execute(argv(args) .. ' >/dev/null 2>&1')
        return a == 0 or (a == true and (c == nil or c == 0))
    end
    local read = env.read or function(args)
        local p = io.popen(argv(args) .. ' 2>/dev/null'); if not p then return '' end
        local s = p:read('*a'); p:close(); return s
    end
    local runtime = env.runtime or '/var/run/modgui-smartphone-uplink'
    local dns_dir = env.runtime or '/var/run/modgui-smartphone-dns'
    local dns_file = dns_dir .. '/resolv.conf'
    local config, health, active = nil, {wan=nil,phone=nil}, 'none'
    local function file(name) return runtime .. '/' .. name end
    local function exists(path) local f=io.open(path,'r'); if f then f:close(); return true end; return false end
    local function write(path, text)
        local f=assert(io.open(path..'.new','w')); f:write(text); f:close()
        if path==dns_file then assert(run({'chmod','644',path..'.new'}),'Unable to expose DNS server list to dnsmasq') end
        assert(os.rename(path..'.new',path))
    end
    local function private_runtime()
        assert(run({'mkdir','-p',runtime}), 'Unable to create runtime directory')
        assert(run({'chmod','700',runtime}), 'Unable to protect runtime directory')
    end
    local function prepare_dns()
        assert(run({'mkdir','-p',dns_dir}),'Unable to create DNS directory')
        if dns_dir~=runtime then assert(run({'chmod','755',dns_dir}),'Unable to permit dnsmasq access') end
    end
    -- Use the raw Lua UCI API available on both old Homeware and OpenWrt;
    -- LuCI-only helpers such as section/set_list/changes may not exist.
    local function section(package, kind, name, values)
        assert(uci:set(package,name,kind), 'Unable to create '..name)
        for k,v in pairs(values) do assert(uci:set(package,name,k,v), 'Unable to set '..name..'.'..k) end
    end
    local function set_list(package, name, option, values)
        if #values==0 then uci:delete(package,name,option)
        else assert(uci:set(package,name,option,values), 'Unable to update '..name..'.'..option) end
    end
    local function settings() return uci:get_all('smartphone','uplink') or {} end
    local function call(name)
        if not safe(name) then return {} end
        assert(bus, 'ubus unavailable')
        return bus:call('network.interface.'..name,'status',{}) or {}
    end
    local function info(name)
        local s=call(name); local address=(s['ipv4-address'] or {})[1] or {}
        local gateway
        for _, r in ipairs(s.route or {}) do
            if r.target=='0.0.0.0' and tonumber(r.mask)==0 then gateway=r.nexthop; break end
        end
        if not gateway then
            for _,r in ipairs(s.inactive and s.inactive.route or {}) do
                if r.target=='0.0.0.0' and tonumber(r.mask)==0 then gateway=r.nexthop; break end
            end
        end
        if gateway=='0.0.0.0' then gateway=nil end
        local dns=s['dns-server'] or {}
        if #dns==0 then dns=s.inactive and s.inactive['dns-server'] or {} end
        return {name=name, dev=s.l3_device or s.device, ip=address.address,
            gateway=gateway, dns=dns, metric=tonumber(s.metric) or 0,
            up=s.up == true and ipv4(address.address) and safe(s.l3_device or s.device)}
    end
    local function usb()
        if env.usb then return env.usb() end
        return read({'/usr/bin/phone_stats.sh','get_usb_info'}):match('\n?HOST_IF|([^\r\n]+)')
    end
    local function pending_changes()
        for _, name in ipairs({'network','firewall','dhcp'}) do
            if read({'uci','changes',name}):match('%S') then error('Sono presenti modifiche di rete non applicate. Salvale prima di procedere.') end
        end
    end
    local function commit(name) assert(uci:commit(name), 'Unable to save '..name) end
    local function find_wan()
        local best, score
        uci:foreach('firewall','zone',function(z)
            if tostring(z.masq)=='1' then
                for _, n in ipairs(words(z.network)) do
                    local s=uci:get_all('network',n)
                    if n~=IFACE and s and s.proto~='dhcpv6' and s.proto~='loopback' and s.auto~='0' then
                        local i=info(n)
                        local v=(i.up and 100 or 0)+(n=='wan' and 10 or 0)+(z.name=='wan' and 1 or 0)
                        if not score or v>score then best={wan=n,zone=z['.name']}; score=v end
                    end
                end
            end
        end)
        assert(best, 'Nessuna WAN IPv4 con zona NAT disponibile.')
        return best
    end
    local function ip(args)
        local a={'ip','-4'}; for _,v in ipairs(args) do a[#a+1]=v end; return run(a)
    end
    local function reserved_check()
        if exists(file('owned')) then return end
        local rules=read({'ip','-4','rule','show'})
        for _, n in ipairs({90,91,100,101}) do
            assert(not ('\n'..rules):match('\n'..n..':'), 'Priorità di routing '..n..' già in uso.')
        end
        for _, n in pairs(TABLES) do
            assert(not read({'ip','-4','route','show','table',n}):match('%S'), 'Tabella di routing '..n..' già in uso.')
        end
        private_runtime()
        write(file('owned'),'1\n')
    end
    local function delete_rules()
        for _, spec in ipairs({{90,TABLES.wan},{91,TABLES.phone},{101,TABLES.active}}) do
            for _=1,8 do if not ip({'rule','del','pref',spec[1],'lookup',spec[2]}) then break end end
        end
        ip({'rule','del','pref',100,'fwmark','0/0xffffffff','lookup','main','suppress_prefixlength',0})
    end
    local function cleanup_routes()
        if not exists(file('owned')) then return end
        delete_rules()
        for _,n in pairs(TABLES) do ip({'route','flush','table',n}) end
        os.remove(file('owned')); os.remove(file('rules'))
    end
    local function route(table_id, i)
        if not i.up then ip({'route','flush','table',table_id}); return false end
        local a={'route','replace','default'}
        if ipv4(i.gateway) then a[#a+1]='via'; a[#a+1]=i.gateway end
        a[#a+1]='dev'; a[#a+1]=i.dev; a[#a+1]='src'; a[#a+1]=i.ip
        if ipv4(i.gateway) then a[#a+1]='onlink' end
        a[#a+1]='table'; a[#a+1]=table_id
        return ip(a)
    end
    local function rules(wan, phone)
        reserved_check()
        local signature=(wan.dev or '')..'|'..(wan.ip or '')..'|'..(phone.dev or '')..'|'..(phone.ip or '')
        local old=io.open(file('rules'),'r'); local previous=old and old:read('*a'); if old then old:close() end
        if previous==signature then return end
        delete_rules()
        -- Probe source addresses use their own tables, including reverse-path
        -- checks. Native marked-policy traffic retains its original routing.
        for _,spec in ipairs({{wan,90,TABLES.wan},{phone,91,TABLES.phone}}) do
            if safe(spec[1].dev) and ipv4(spec[1].ip) then
                for _,target in ipairs(TARGETS) do
                    assert(ip({'rule','add','pref',spec[2],'from',spec[1].ip..'/32','to',target..'/32','lookup',spec[3]}), 'Impossibile creare regola di controllo linea.')
                end
            end
        end
        assert(ip({'rule','add','pref',100,'fwmark','0/0xffffffff','lookup','main','suppress_prefixlength',0}), 'Il firmware non supporta le regole di fallback richieste.')
        assert(ip({'rule','add','pref',101,'fwmark','0/0xffffffff','lookup',TABLES.active}), 'Impossibile attivare la tabella di fallback.')
        write(file('rules'),signature)
    end
    local function probe(i)
        if not i.up then return false end
        for _,target in ipairs(TARGETS) do
            if run({'ping','-4','-c','1','-W','1','-w','2','-I',i.ip,target}) then return true end
        end
        return false
    end
    local function resolver(i)
        if not config.dns_managed then return end
        local lines={}; for _,server in ipairs(i.dns) do if ipv4(server) then lines[#lines+1]='nameserver '..server end end
        if #lines==0 then return end
        local content=table.concat(lines,'\n')..'\n'
        local f=io.open(dns_file,'r'); local old=f and f:read('*a'); if f then f:close() end
        if old~=content then prepare_dns(); write(dns_file,content) end
    end
    local function status_write(wan, phone, message)
        local function label(h) return h and h.up and 'online' or h and h.bad>=3 and 'offline' or 'checking' end
        local s={mode=config.mode, wan=config.wan, active=active, message=message or '',
            wan_up=health.wan and health.wan.up or false, phone_up=health.phone and health.phone.up or false,
            wan_health=label(health.wan), phone_health=label(health.phone),
            phone_ip=phone.ip, gateway=phone.gateway, timestamp=os.time()}
        write(file('status.json'),json.encode(s))
    end
    local self={}
    function self.release() cleanup_routes() end
    function self.cleanup()
        private_runtime(); write(file('stop'),'1')
        cleanup_routes()
    end
    function self.stop()
        local c=settings()
        assert(c.owner==nil or c.owner==OWNER, 'Configurazione Smartphone non gestita da questa app.')
        if c.owner~=OWNER then return true end
        uci:set('smartphone','uplink','enabled','0'); commit('smartphone')
        self.cleanup(); run({'/etc/init.d/modgui-smartphone-uplink','stop_uplink'})
        run({'ifdown',IFACE})
        if uci:get('network',IFACE,'modgui_owner')==OWNER then uci:delete('network',IFACE); commit('network') end
        if safe(c.zone) then
            local list=words(uci:get('firewall',c.zone,'network')); local kept={}
            for _,v in ipairs(list) do if v~=IFACE then kept[#kept+1]=v end end
            set_list('firewall',c.zone,'network',kept); commit('firewall')
        end
        if c.dns_managed=='1' and uci:get('dhcp',c.dns_section,'resolvfile')==dns_file then
            if c.old_resolv_present=='1' then uci:set('dhcp',c.dns_section,'resolvfile',c.old_resolv or '')
            else uci:delete('dhcp',c.dns_section,'resolvfile') end
            commit('dhcp'); run({'/etc/init.d/dnsmasq','reload'})
        end
        uci:set('smartphone','uplink','mode','off'); commit('smartphone')
        run({'/etc/init.d/network','reload'}); run({'/etc/init.d/firewall','reload'})
        os.remove(file('status.json')); return true
    end
    function self.apply(mode)
        assert(mode=='link' or mode=='fallback' or mode=='primary','Modalità tethering non valida.')
        pending_changes()
        local dev=usb(); assert(safe(dev),'Nessuna interfaccia USB di tethering rilevata.')
        local existing=uci:get('network',IFACE)
        assert(not existing or uci:get('network',IFACE,'modgui_owner')==OWNER,'Interfaccia '..IFACE..' già utilizzata da altra configurazione.')
        local c=settings(); assert(not c.owner or c.owner==OWNER,'Configurazione Smartphone già in uso.')
        local was_enabled=c.enabled=='1'
        local cfg=env.config_path or '/etc/config/smartphone'
        if not exists(cfg) then local f=assert(io.open(cfg,'w')); f:close(); uci:unload('smartphone') end
        local target=c.enabled=='1' and c.owner==OWNER and safe(c.wan) and safe(c.zone) and {wan=c.wan,zone=c.zone} or find_wan()
        if mode~='link' then
            reserved_check()
            local live=read({'ip','-4','rule','show'})
            if not live:match('suppress_prefixlength 0') then
                local supported=ip({'rule','add','pref',100,'fwmark','0/0xffffffff','lookup','main','suppress_prefixlength',0})
                if not supported then cleanup_routes(); error('Il firmware non supporta le regole IPv4 di fallback richieste. È disponibile il solo collegamento DHCP.') end
                ip({'rule','del','pref',100,'fwmark','0/0xffffffff','lookup','main','suppress_prefixlength',0})
            end
        end
        local before={network=uci:get_all('network',IFACE),smartphone=uci:get_all('smartphone','uplink'),
            member=contains(uci:get('firewall',target.zone,'network'),IFACE)}
        uci:foreach('dhcp','dnsmasq',function(s)
            if not before.dns_section then before.dns_section=s['.name']; before.resolv=s.resolvfile end
        end)
        local ok,err=pcall(function()
            if c.enabled=='1' then self.stop(); uci:unload('smartphone'); c=settings() end
            private_runtime(); os.remove(file('stop'))
            local metric=1000
            local dump=bus:call('network.interface','dump',{}) or {}
            for _,s in ipairs(dump.interface or {}) do if s.interface~=IFACE then metric=math.max(metric,(tonumber(s.metric) or 0)+1000) end end
            assert(metric<2147483647,'Metriche WAN non supportate.')
            section('network','interface',IFACE,{proto='dhcp',ifname=dev,device=dev,auto='1',
                defaultroute=mode=='link' and '0' or '1',metric=tostring(metric),peerdns='0',delegate='0',ipv6='0',modgui_owner=OWNER})
            local list=words(uci:get('firewall',target.zone,'network'))
            if not contains(list,IFACE) then list[#list+1]=IFACE end
            set_list('firewall',target.zone,'network',list)
            uci:delete('smartphone','uplink')
            section('smartphone','uplink','uplink',{owner=OWNER,enabled='1',mode=mode,wan=target.wan,zone=target.zone})
            local dns
            uci:foreach('dhcp','dnsmasq',function(s) if not dns then dns=s end end)
            if mode~='link' and dns and dns.noresolv~='1' then
                local old=dns.resolvfile or '/tmp/resolv.conf.auto'
                local original=io.open(old,'r'); local data=original and original:read('*a') or ''; if original then original:close() end
                prepare_dns(); write(dns_file,data)
                uci:set('smartphone','uplink','dns_managed','1')
                uci:set('smartphone','uplink','dns_section',dns['.name'])
                uci:set('smartphone','uplink','old_resolv_present',dns.resolvfile and '1' or '0')
                uci:set('smartphone','uplink','old_resolv',dns.resolvfile or '')
                uci:set('dhcp',dns['.name'],'resolvfile',dns_file)
            end
            for _,name in ipairs({'network','firewall','dhcp','smartphone'}) do commit(name) end
            assert(run({'/etc/init.d/network','reload'}),'Ricaricamento rete non riuscito.')
            assert(run({'/etc/init.d/firewall','reload'}),'Ricaricamento firewall non riuscito.')
            run({'/etc/init.d/dnsmasq','reload'})
            assert(run({'/etc/init.d/modgui-smartphone-uplink','enable'}),'Impossibile abilitare il servizio tethering.')
            assert(run({'/etc/init.d/modgui-smartphone-uplink','start'}),'Impossibile avviare il servizio tethering.')
        end)
        if not ok then
            self.cleanup()
            run({'/etc/init.d/modgui-smartphone-uplink','stop_uplink'})
            -- Restore only the app's sections/fields, not whole configurations
            -- that another page or service may have changed in the meantime.
            for _,name in ipairs({'network','firewall','dhcp','smartphone'}) do uci:unload(name) end
            local function restore_section(package,name,old)
                uci:delete(package,name)
                if old then
                    local values={}; for k,v in pairs(old) do if k:sub(1,1)~='.' then values[k]=v end end
                    section(package,old['.type'],name,values)
                end
            end
            restore_section('network',IFACE,before.network)
            restore_section('smartphone','uplink',before.smartphone)
            local kept={}; for _,v in ipairs(words(uci:get('firewall',target.zone,'network'))) do if v~=IFACE then kept[#kept+1]=v end end
            if before.member then kept[#kept+1]=IFACE end
            set_list('firewall',target.zone,'network',kept)
            if before.dns_section and uci:get('dhcp',before.dns_section,'resolvfile')==dns_file then
                if before.resolv then uci:set('dhcp',before.dns_section,'resolvfile',before.resolv)
                else uci:delete('dhcp',before.dns_section,'resolvfile') end
            end
            for _,name in ipairs({'network','firewall','dhcp','smartphone'}) do commit(name) end
            run({'/etc/init.d/network','reload'}); run({'/etc/init.d/firewall','reload'}); run({'/etc/init.d/dnsmasq','reload'})
            if was_enabled then run({'/etc/init.d/modgui-smartphone-uplink','start'}) end
            error(err)
        end
        return true
    end
    function self.step()
        if exists(file('control.lock/pid')) then return true end
        uci:unload('smartphone'); uci:unload('network')
        config=settings(); config.dns_managed=config.dns_managed=='1'
        if config.enabled~='1' or exists(file('stop')) then return false end
        assert(safe(config.wan),'WAN configurata non valida.')
        local dev=usb()
        local rebind_message
        if safe(dev) and uci:get('network',IFACE,'ifname')~=dev then
            if read({'uci','changes','network'}):match('%S') then rebind_message='Salvare le modifiche di rete in sospeso per ricollegare il telefono.'
            else
                uci:set('network',IFACE,'ifname',dev); uci:set('network',IFACE,'device',dev); commit('network'); run({'/etc/init.d/network','reload'})
            end
        end
        local wan,phone=info(config.wan),info(IFACE)
        assert(not (wan.up and phone.up and wan.ip==phone.ip), 'Le due linee hanno lo stesso indirizzo IPv4. Cambiare la rete USB del telefono.')
        if config.mode=='link' then active='none'; status_write(wan,phone,'Solo collegamento DHCP'); return true end
        rules(wan,phone)
        local wroute,proute=route(TABLES.wan,wan),route(TABLES.phone,phone)
        health.wan=M.health(health.wan,wroute and probe(wan),wan.up)
        health.phone=M.health(health.phone,proute and probe(phone),phone.up)
        if exists(file('stop')) then return false end
        if exists(file('control.lock/pid')) then return true end
        local chosen=M.choose(config.mode,health)
        if chosen=='none' then ip({'route','flush','table',TABLES.active}); active='none'
        else
            local i=chosen=='phone' and phone or wan
            assert(route(TABLES.active,i),'Impossibile applicare la rotta selezionata.')
            active=chosen; resolver(i)
        end
        status_write(wan,phone,rebind_message or (chosen=='none' and 'Verifica connettività in corso o entrambe le linee non raggiungibili.' or ''))
        return true
    end
    function self.status()
        local c=settings(); local state={}
        local f=io.open(file('status.json'),'r'); if f then state=json.decode(f:read('*a')) or {}; f:close() end
        local out={UPLINK_MODE=c.enabled=='1' and c.mode or 'off',UPLINK_WAN=c.wan,
            UPLINK_IPV4=state.phone_ip,UPLINK_GATEWAY=state.gateway,
            UPLINK_ACTIVE=state.active or 'none',UPLINK_MESSAGE=state.message,
            UPLINK_WAN_HEALTH=state.wan_health or 'checking',
            UPLINK_PHONE_HEALTH=state.phone_health or 'checking'}
        if c.enabled=='1' and (not state.timestamp or os.time()-state.timestamp>45) then out.UPLINK_MESSAGE='Avvio DHCP/monitor in corso o monitor non attivo.' end
        for k,v in pairs(out) do if v then print(k..'|'..tostring(v):gsub('[\r\n|]',' ')) end end
    end
    function self.control(action)
        assert(action=='stop' or action=='link' or action=='fallback' or action=='primary','Azione tethering non valida.')
        private_runtime()
        local pid=env.pid
        if not pid then
            local f=io.open('/proc/self/stat','r'); pid=f and f:read('*l'):match('^(%d+)'); if f then f:close() end
        end
        assert(pid,'Impossibile identificare il processo di configurazione.')
        local lock=file('control.lock')
        if not run({'mkdir',lock}) then
            local f=io.open(lock..'/pid','r'); local pid=f and f:read('*a'); if f then f:close() end
            local stale=pid and pid:match('^%d+$') and not run({'kill','-0',pid})
            if not pid then
                local ok,lfs=pcall(require,'lfs'); local a=ok and lfs.attributes(lock)
                stale=a and os.time()-a.modification>60
            end
            assert(stale,'Un’altra configurazione tethering è già in corso.')
            os.remove(lock..'/pid'); assert(run({'rmdir',lock}) and run({'mkdir',lock}),'Lock tethering non disponibile.')
        end
        write(lock..'/pid',tostring(pid))
        local ok,err=pcall(function() if action=='stop' then self.stop() else self.apply(action) end end)
        os.remove(lock..'/pid'); run({'rmdir',lock})
        if not ok then error(err) end
        return true
    end
    return self
end

if arg and arg[0] and arg[0]:match('/uplink%.lua$') then
    local app; local action=arg[1]
    local ok,err=pcall(function()
        app=M.new()
        if action=='status' then app.status()
        elseif action=='stop' then app.control('stop'); print('SUCCESS|Tethering disattivato; configurazione precedente ripristinata.')
        elseif action=='cleanup' then app.cleanup()
        elseif action=='daemon' then
            while app.step() do os.execute('sleep 5') end
        else app.control(action); print('SUCCESS|Configurazione tethering avviata. Attendere DHCP e verifica delle linee.') end
    end)
    if not ok then if app and action=='daemon' then pcall(app.release) end; print('ERROR|'..tostring(err):gsub('[\r\n|]',' ')); os.exit(1) end
end
return M
