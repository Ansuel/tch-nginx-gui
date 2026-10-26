-- Coordinate manual bridging with firmware-owned WAN sensing.
local proxy = require("datamodel")
local M = {}
local wan = "uci.network.interface.@wan."
local lan = "uci.network.interface.@lan.ifname"
local config = "uci.network.config."
local sensing = "uci.wansensing.global.enable"

local function get(path)
    local value = proxy.get(path)
    return value and value[1] and value[1].value
end
M.get = get

-- The web runtime wraps configuration strings in userdata. Concatenation
-- supports those values and preserves their taint; table.concat does not.
local function join(values, separator)
    local result = ""
    for index, value in ipairs(values) do
        if index > 1 then result = result .. separator end
        result = result .. value
    end
    return result
end

local function words(value)
    local result, seen = {}, {}
    for token in (value or ""):gmatch("%S+") do
        local item = token
        -- Identifiers are used as set keys as well as values. Lua does not
        -- equate a tainted userdata key with its plain-string counterpart.
        -- Normalize only interface-name tokens, never arbitrary UI content.
        if string.untaint and item:match("^[%w_.:@%-]+$") then item = string.untaint(item) end
        if not seen[item] then
            result[#result + 1], seen[item] = item, true
        end
    end
    return result, seen
end

local function without(value, removed)
    local _, excluded = words(removed)
    local result = {}
    for _, item in ipairs(words(value)) do
        if not excluded[item] then result[#result + 1] = item end
    end
    return join(result, " ")
end

function M.isBridged()
    return get(config .. "wan_mode") == "bridge"
end

function M.getUplink()
    local saved = M.isBridged() and get(config .. "bridge_ifname")
    if saved and saved ~= "" then return saved end
    local current = get(wan .. "ifname") or ""
    if M.isBridged() and current == "br-lan" then
        -- Older GUI bridges kept no uplink metadata. Recover only an
        -- unambiguous WAN-designated Ethernet port already in this bridge.
        local _, members = words(get(lan))
        local candidate
        for _, entry in ipairs(proxy.getPN("uci.ethernet.port.", true) or {}) do
            local name = entry.path:match("@([^%.]+)%.$")
            if name and members[name] and get(entry.path .. "wan") == "1" then
                if candidate then return current end
                candidate = name
            end
        end
        if candidate then return candidate end
    end
    return current
end

-- Resolve complete port lists as well as nested netifd @interface aliases.
function M.resolveUplinks(value, seen, depth)
    seen, depth = seen or {}, depth or 0
    if not value or value == "" or seen[value] or depth > 16 then return nil end
    seen[value] = true
    local result = {}
    for _, name in ipairs(words(value)) do
        if name:sub(1, 1) == "@" then
            local path = "uci.network.interface." .. name .. "."
            local child = get(path .. "ifname")
            if not child or child == "" then child = get(path .. "device") end
            local resolved = M.resolveUplinks(child, seen, depth + 1)
            if not resolved then return nil end
            for _, member in ipairs(words(resolved)) do result[#result + 1] = member end
        elseif name == "br-lan" or name == "lan" or name == "lo" then
            return nil
        else
            result[#result + 1] = name
        end
    end
    seen[value] = nil
    if #result == 0 then return nil end
    return join(words(join(result, " ")), " ")
end

function M.resolveUplink(value)
    local resolved = M.resolveUplinks(value)
    if resolved and not resolved:find("%s") then return resolved end
end

function M.vlanContext(uplink)
    local ifname = M.resolveUplink(uplink or M.getUplink()) or ""
    local device
    for _, entry in ipairs(proxy.getPN("uci.network.device.", true) or {}) do
        local kind = get(entry.path .. "type")
        if get(entry.path .. "name") == ifname and (kind == "8021q" or kind == "8021ad") then
            device = entry.path
            break
        end
    end
    local parent = device and get(device .. "ifname")
    local base, vid = ifname:match("^(.+)%.(%d+)$")
    local connection = parent or base or ifname
    local suffix = connection:match("^atm") and "atmwan" or connection
    local path = device or ("uci.network.device.@wan" .. suffix .. ".")
    return {
        connection = connection,
        path = path,
        vid = device and get(device .. "vid") or vid or get(path .. "vid") or "",
        difname = device and parent or base or "",
        notation = not device and base and "dotnot" or "devnot",
        vlanType = device and get(device .. "type") or "8021q",
    }
end

local function xtmDevices(kind)
    local result = {}
    for _, entry in ipairs(proxy.getPN("uci.xtm." .. kind .. "device.", true) or {}) do
        local name = entry.path:match("@([^%.]+)%.$")
        if name then result[#result + 1] = {name = name, path = entry.path} end
    end
    return result
end

function M.isDslInterface(ifname, kind)
    for _, entry in ipairs(xtmDevices(kind)) do
        if entry.name == ifname then return true end
    end
    return ifname:match("^" .. kind) ~= nil
end

function M.ethernetPort(fallback)
    local current = M.vlanContext().connection
    if current ~= "" and get("uci.ethernet.port.@" .. current .. ".wan") == "1" then return current end
    local chosen
    for _, entry in ipairs(proxy.getPN("uci.ethernet.port.", true) or {}) do
        if get(entry.path .. "wan") == "1" then
            local name = entry.path:match("@([^%.]+)%.$")
            if name == fallback then return name end
            chosen = chosen or name
        end
    end
    return chosen or fallback
end

function M.ethernetLink()
    local port = M.ethernetPort()
    local stats = {operstate = "down", carrier = "0", speed = "0"}
    if port and M.vlanContext().connection == port then
        for key in pairs(stats) do
            stats[key] = get("sys.class.net.@" .. port .. "." .. key) or stats[key]
        end
    end
    return stats
end

-- Preserve an already selected port/PVC/VLAN. On a technology change prefer
-- real XTM devices and data VLANs over fabricated firmware-specific names.
function M.broadbandUplink(kind, ethname)
    local channel = M.vlanContext()
    local dsl = kind == "adsl" and "atm" or kind == "vdsl" and "ptm"
    local current = channel.connection
    if (dsl and M.isDslInterface(current, dsl)) or (not dsl and current == ethname) then
        return M.getUplink()
    end
    local parent = ethname
    if dsl then
        local candidates = xtmDevices(dsl)
        local chosen = candidates[1]
        for _, entry in ipairs(candidates) do
            if entry.name == "atmwan" or (get(entry.path .. "vpi") == "8" and get(entry.path .. "vci") == "35") then
                chosen = entry
                break
            end
        end
        if not chosen then
            return nil, T"No device is available for the selected DSL technology"
        end
        parent = chosen.name
    end
    local vlans, preferred = {}, nil
    for _, entry in ipairs(proxy.getPN("uci.network.device.", true) or {}) do
        if get(entry.path .. "ifname") == parent and get(entry.path .. "type") == "8021q" then
            local name = get(entry.path .. "name")
            if name and name ~= "" then
                vlans[#vlans + 1] = name
                if name:match("^wan") or name == "vlan_wan" or name == "vlan_data" then preferred = name end
            end
        end
    end
    return preferred or (#vlans == 1 and vlans[1]) or parent
end

function M.lanWithout(removed)
    return without(get(lan), removed)
end

function M.lanWith(added)
    local members, seen = words(get(lan))
    for _, item in ipairs(words(added)) do
        if not seen[item] then members[#members + 1], seen[item] = item, true end
    end
    return join(members, " ")
end

-- Commit the disable before touching the network. The native stop command
-- handles both procd firmware and the older service_start/service_stop daemon.
local function suspendSensing()
    if get(sensing) ~= "1" then return true end
    local ok = proxy.set(sensing, "0")
    if not ok then return false, T"Unable to disable WanSensing" end
    ok = proxy.apply()
    if not ok then return false, T"Unable to disable WanSensing" end
    -- Legacy stop() may return failure when the commit/apply restart already
    -- stopped the daemon, or success after an unsuccessful kill followed by rm.
    -- Verify absence instead, allowing a short asynchronous procd shutdown.
    local status = os.execute([[
/etc/init.d/wansensing stop >/dev/null 2>&1
command -v pidof >/dev/null 2>&1 || exit 1
for attempt in 1 2 3; do
    pidof wansensing.lua >/dev/null 2>&1 || exit 0
    sleep 1
done
exit 1
]])
    if status ~= 0 and status ~= true then
        return false, T"Unable to stop WanSensing; bridge mode was not activated"
    end
    return true
end

local function membership(ifname, previous)
    local resolved = M.resolveUplinks(ifname)
    if not resolved then return nil end
    local members, present = words(without(get(lan), previous))
    local added = {}
    for _, member in ipairs(words(resolved)) do
        if not present[member] then
            members[#members + 1], added[#added + 1] = member, member
        end
    end
    return join(members, " "), join(added, " ")
end

local function bridgeable(ifname)
    local resolved = M.resolveUplinks(ifname)
    if not resolved then return false, T"Select a physical WAN interface before enabling bridge mode" end
    for _, member in ipairs(words(resolved)) do
        -- A PPPoA PVC is not an Ethernet netdev. Changing its ULP would also
        -- change the operator encapsulation, so do not silently convert it.
        local parent, seen = member, {}
        for _ = 1, 16 do
            if seen[parent] then return false, T"The selected VLAN has a cyclic parent interface" end
            seen[parent] = true
            local nextParent
            for _, entry in ipairs(proxy.getPN("uci.network.device.", true) or {}) do
                local kind = get(entry.path .. "type")
                if get(entry.path .. "name") == parent and (kind == "8021q" or kind == "8021ad") then
                    nextParent = get(entry.path .. "ifname")
                    break
                end
            end
            nextParent = nextParent or parent:match("^(.+)%.%d+$")
            if not nextParent or nextParent == "" then break end
            parent = nextParent
        end
        local ulp = get("uci.xtm.atmdevice.@" .. parent .. ".ulp")
        if ulp == "ppp" then
            return false, T"Transparent bridging requires an Ethernet ATM PVC; the selected PVC uses PPPoA"
        end
    end
    return true
end
M.canBridge = bridgeable

local function suspendClients(values, ifname)
    local clients, stopped = {}, {}
    for name, auto in (get(config .. "bridge_client_autos") or ""):gmatch("([%w_%-]+)=([01]?)") do
        clients[name] = auto
    end
    local _, ports = words(M.resolveUplinks(ifname))
    local candidates = {wantag = true}
    for _, entry in ipairs(proxy.getPN("uci.network.interface.", true) or {}) do
        local name = entry.path:match("@([%w_%-]+)%.$")
        local proto = get(entry.path .. "proto")
        if name and name ~= "lan" and name ~= "wan" and
            (proto == "dhcp" or proto == "dhcpv6" or proto == "pppoe" or proto == "pppoa") then
            for _, port in ipairs(words(M.resolveUplinks(get(entry.path .. "ifname")))) do
                if ports[port] then candidates[name] = true end
            end
        end
    end
    for name in pairs(candidates) do
        local path = "uci.network.interface.@" .. name .. "."
        if clients[name] == nil and (get(path .. "proto") ~= nil or get(path .. "auto") ~= nil) then
            local auto = get(path .. "auto") or ""
            if auto == "" or auto == "0" or auto == "1" then
                clients[name] = auto
                values[path .. "auto"] = "0"
                stopped[#stopped + 1] = name
            end
        end
    end
    local saved = {}
    for name, auto in pairs(clients) do saved[#saved + 1] = name .. "=" .. auto end
    table.sort(saved)
    values[config .. "bridge_client_autos"] = join(saved, " ")
    return stopped
end

local function stopClients(clients)
    for _, name in ipairs(clients) do os.execute("ifdown " .. name .. " >/dev/null 2>&1") end
end

local lanDhcp = "uci.dhcp.dhcp.@lan."
local lanServiceOptions = {ignore = "1", dhcpv4 = "disabled", dhcpv6 = "disabled", ra = "disabled", ndp = "disabled"}

local function restartLanServers()
    local status = os.execute([[
if [ -x /etc/init.d/dnsmasq ]; then
    /etc/init.d/dnsmasq restart >/dev/null 2>&1 || exit 1
fi
[ ! -x /etc/init.d/odhcpd ] || /etc/init.d/odhcpd restart >/dev/null 2>&1
]])
    return status == 0 or status == true
end

local function suspendLanServices()
    if (get(config .. "bridge_lan_dhcp") or "") ~= "" then return true end
    local values, saved = {}, {}
    for name, disabled in pairs(lanServiceOptions) do
        local original = get(lanDhcp .. name)
        if original ~= nil then
            saved[#saved + 1] = name .. "=" .. original
            values[lanDhcp .. name] = disabled
        end
    end
    if #saved == 0 then return true end
    table.sort(saved)
    values[config .. "bridge_lan_dhcp"] = join(saved, " ")
    local ok, err = proxy.set(values)
    if ok then ok, err = proxy.apply() end
    if not ok then return false, err end
    if not restartLanServers() then return false, T"Unable to suspend the LAN DHCP/IPv6 servers before bridging" end
    return true
end

local function restoreLanServices(saved)
    local values = {[config .. "bridge_lan_dhcp"] = ""}
    for name, original in saved:gmatch("([%w_]+)=([%w_%-]*)") do
        if lanServiceOptions[name] then values[lanDhcp .. name] = original end
    end
    local ok, err = proxy.set(values)
    if ok then ok, err = proxy.apply() end
    if not ok then return false, err end
    if not restartLanServers() then return false, T"Unable to restore the LAN DHCP/IPv6 servers" end
    return true
end

local relayList = "uci.network.interface.@lan.pppoerelay."
local function suspendRelay(ifname)
    local _, uplinks = words(M.resolveUplinks(ifname))
    local saved = get(config .. "bridge_lan_relays") or ""
    local values, changed = {}, false
    for _, entry in ipairs(proxy.getPN(relayList, true) or {}) do
        local index = entry.path:match("@(%d+)%.$")
        local device = get(entry.path .. "value") or ""
        local resolved = M.resolveUplinks(device)
        local overlap = false
        for _, port in ipairs(words(resolved)) do if uplinks[port] then overlap = true end end
        if index and overlap and device:match("^[%w_.:@%-]+$") then
            saved = saved .. " " .. index .. "=" .. device
            values[entry.path .. "value"] = ""
            changed = true
        end
    end
    if not changed then return true end
    values[config .. "bridge_lan_relays"] = saved
    local ok, err = proxy.set(values)
    if ok then ok, err = proxy.apply() end
    if not ok then return false, err end
    local status = os.execute("[ ! -x /etc/init.d/pppoe-relay-tch ] || /etc/init.d/pppoe-relay-tch reload >/dev/null 2>&1")
    if status ~= 0 and status ~= true then return false, T"Unable to suspend the PPPoE relay on the selected WAN" end
    return true
end

local qosDevices = "uci.qos.device."
local function protectRunnerQueues(members)
    local group = get("uci.qos.interface.@lan.classgroup")
    if not group or not group:match("^[%w_%-]+$") then return true end
    local ports = proxy.getPN("uci.ethernet.port.", true) or {}
    local overlaps = false
    for _, port in ipairs(ports) do
        local name = port.path:match("@([%w_%-]+)%.$")
        if name and get(port.path .. "wan") == "1" then
            for _, member in ipairs(words(members)) do
                if M.vlanContext(member).connection == name then overlaps = true end
            end
        end
    end
    if not overlaps or os.execute("[ -x /usr/bin/setuprunner ]") ~= 0 then return true end
    -- Runner's LAN interface fallback also configures WAN-designated bridge
    -- members, replacing their WAN queues with the LAN classgroup. Complete
    -- per-device LAN profiles make its native setup respect the port roles.
    local existing = {}
    local inventory = proxy.getPN(qosDevices, true)
    if not inventory then return false, T"Unable to inspect Ethernet QoS profiles" end
    for _, entry in ipairs(inventory) do existing[entry.path] = true end
    local created, values = {}, {}
    local saved = get(config .. "bridge_qos_devices") or ""
    local previousSaved = saved
    local function abort(message)
        for _, name in ipairs(created) do proxy.del(qosDevices .. "@" .. name .. ".") end
        proxy.set(config .. "bridge_qos_devices", previousSaved)
        return false, message
    end
    for _, port in ipairs(ports) do
        local name = port.path:match("@([%w_%-]+)%.$")
        if name then
            local path = qosDevices .. "@" .. name .. "."
            if not existing[path] then
                local profile = group
                if get(port.path .. "wan") == "1" then
                    profile = get("uci.qos.interface.@wan.classgroup")
                end
                if not profile or not profile:match("^[%w_%-]+$") then
                    return abort(T"Unable to inherit the Ethernet QoS classgroup")
                end
                local ok, err = proxy.add(qosDevices, name)
                if not ok then return abort(err) end
                created[#created + 1] = name
                values[path .. "classgroup"] = profile
                saved = saved .. " " .. name .. "=" .. profile
            end
        end
    end
    if #created == 0 then return true end
    values[config .. "bridge_qos_devices"] = saved
    local ok, err = proxy.set(values)
    if not ok then return abort(err) end
    ok, err = proxy.apply()
    if not ok then return false, err end
    local status = os.execute("/etc/init.d/ethernet reload >/dev/null 2>&1")
    if status ~= 0 and status ~= true then return false, T"Unable to configure Ethernet bridge queues" end
    return true
end

local function restoreRunnerQueues(saved)
    for name, group in saved:gmatch("([%w_%-]+)=([%w_%-]+)") do
        local path = qosDevices .. "@" .. name .. "."
        -- Retain profiles the user changed while bridge mode was active.
        local unchanged = get(path .. "classgroup") == group
        for _, option in ipairs({"enable", "switchclassification", "pcp", "force_pcp"}) do
            local value = get(path .. option)
            if value and value ~= "" then unchanged = false end
        end
        if unchanged then
            local ok, err = proxy.del(path)
            if not ok then return false, err end
        end
    end
    return proxy.set(config .. "bridge_qos_devices", "")
end

function M.setUplink(ifname, previousUplink)
    if not M.isBridged() then return proxy.set(wan .. "ifname", ifname) end
    local valid, message = bridgeable(ifname)
    if not valid then return false, message end
    local saved = get(config .. "bridge_ifname")
    local previous = get(config .. "bridge_added_ifnames")
    if not saved or saved == "" then previous = previousUplink or M.resolveUplinks(M.getUplink()) end
    local members, added = membership(ifname, previous)
    if not members then return false, T"Select a physical WAN interface before enabling bridge mode" end
    local relayOk, relayError = suspendRelay(ifname)
    if not relayOk then return false, relayError end
    local qosOk, qosError = protectRunnerQueues(members)
    if not qosOk then return false, qosError end
    local values = {
        [lan] = members,
        [config .. "bridge_ifname"] = ifname,
        [config .. "bridge_added_ifnames"] = added,
    }
    -- A local connection in bridge mode must continue to run on br-lan.
    if get(wan .. "ifname") ~= "br-lan" then values[wan .. "ifname"] = ifname end
    local stopped = suspendClients(values, ifname)
    local ok, err = proxy.set(values)
    if ok then stopClients(stopped) end
    return ok, err
end

function M.enter()
    if M.isBridged() and (get(config .. "bridge_ifname") or "") ~= "" then
        local ok, err = suspendSensing()
        if not ok then return false, err end
        ok, err = suspendLanServices()
        if not ok then return false, err end
        ok, err = suspendRelay(M.getUplink())
        if not ok then return false, err end
        return protectRunnerQueues(get(lan))
    end
    local ifname = M.getUplink()
    local valid, message = bridgeable(ifname)
    if not valid then return false, message end
    local members, added = membership(ifname)
    if not members then return false, T"Select a physical WAN interface before enabling bridge mode" end
    if M.isBridged() then added = M.resolveUplinks(ifname) end
    local previousSensing = get(sensing) or ""
    local previousProto = get(wan .. "proto") or "dhcp"
    local alreadyBridged = M.isBridged()
    if previousProto == "bridge" then previousProto = "dhcp" end
    local ok, err = suspendSensing()
    if not ok then return false, err end
    ok, err = suspendLanServices()
    if not ok then return false, err end
    ok, err = suspendRelay(ifname)
    if not ok then return false, err end
    ok, err = protectRunnerQueues(members)
    if not ok then return false, err end
    local values = {
        [config .. "bridge_ifname"] = ifname,
        [config .. "bridge_proto"] = previousProto,
        [config .. "bridge_wansensing"] = previousSensing,
        [config .. "bridge_added_ifnames"] = added,
        [config .. "wan_mode"] = "bridge",
        [wan .. "proto"] = alreadyBridged and get(wan .. "proto") or "bridge",
        [wan .. "ifname"] = alreadyBridged and get(wan .. "ifname") or ifname,
        [lan] = members,
    }
    local wanType = get(wan .. "type")
    if wanType ~= nil then
        values[config .. "bridge_wan_type"] = wanType
        values[wan .. "type"] = ""
    end
    local stopped = suspendClients(values, ifname)
    ok, err = proxy.set(values)
    if ok then stopClients(stopped) end
    return ok, err
end

function M.leave(mode, enable)
    local values = {[wan .. "proto"] = mode, [config .. "wan_mode"] = mode}
    if M.isBridged() then
        local ifname = M.getUplink()
        local member = M.resolveUplinks(ifname)
        if not member then return false, T"Select a physical WAN interface before leaving bridge mode" end
        local added = get(config .. "bridge_added_ifnames")
        -- Legacy bridges do not have a saved list of ports added by the GUI.
        if added == nil or get(config .. "bridge_ifname") == "" then added = member end
        -- Some defaults already list the designated WAN in LAN before the
        -- GUI adopts it. Routed mode must still detach that selected uplink
        -- before restoring LAN DHCP/RA services.
        local physical = M.vlanContext(ifname).connection
        if get("uci.ethernet.port.@" .. physical .. ".wan") == "1" then
            added = (added or "") .. " " .. member
        end
        values[lan] = without(get(lan), added)
        values[wan .. "ifname"] = ifname
        local saved = get(config .. "bridge_wansensing")
        if enable == nil and (saved == "0" or saved == "1") then enable = saved end
        local auto = get(config .. "bridge_wantag_auto")
        if auto and auto ~= "" then values["uci.network.interface.@wantag.auto"] = auto end
        local wanType = get(config .. "bridge_wan_type")
        if wanType and wanType ~= "" then values[wan .. "type"] = wanType end
        for name, auto in (get(config .. "bridge_client_autos") or ""):gmatch("([%w_%-]+)=([01]?)") do
            local path = "uci.network.interface.@" .. name .. "."
            if get(path .. "proto") ~= nil or get(path .. "auto") ~= nil then values[path .. "auto"] = auto end
        end
        for index, device in (get(config .. "bridge_lan_relays") or ""):gmatch("(%d+)=([%w_.:@%-]+)") do
            values[relayList .. "@" .. index .. ".value"] = device
        end
        values[config .. "bridge_lan_relays"] = ""
        for _, key in ipairs({"ifname", "proto", "wansensing", "added_ifnames", "wantag_auto", "wan_type", "client_autos"}) do
            values[config .. "bridge_" .. key] = ""
        end
    end
    if enable ~= nil and get(sensing) ~= nil then values[sensing] = enable end
    local ok, err = proxy.set(values)
    local savedLan = get(config .. "bridge_lan_dhcp") or ""
    local savedQos = get(config .. "bridge_qos_devices") or ""
    if not ok or (savedLan == "" and savedQos == "") then return ok, err end
    -- Detach the WAN port before allowing LAN DHCP/RA responses again.
    ok, err = proxy.apply()
    if not ok then return false, err end
    local status = os.execute("/etc/init.d/network reload >/dev/null 2>&1")
    if status ~= 0 and status ~= true then return false, T"Unable to restore the routed network before enabling LAN services" end
    if savedLan ~= "" then
        ok, err = restoreLanServices(savedLan)
        if not ok then return false, err end
    end
    if savedQos ~= "" then return restoreRunnerQueues(savedQos) end
    return true
end

function M.setSensing(enable)
    if enable == "1" then
        local l2 = proxy.getPN("uci.wansensing.L2State.", true)
        local l3 = proxy.getPN("uci.wansensing.L3State.", true)
        if l2 and l3 and #l2 == 0 and #l3 == 0 then
            return false, T"WanSensing has no configured detection states in this firmware"
        end
    end
    if enable == "1" and M.isBridged() then
        local mode = get(config .. "bridge_proto")
        if mode ~= "pppoe" and mode ~= "pppoa" and mode ~= "static" then mode = "dhcp" end
        return M.leave(mode, "1")
    end
    return proxy.set(sensing, enable)
end

function M.setLocalProtocol(mode)
    local ifname = mode == "bridge" and M.getUplink() or "br-lan"
    if mode == "bridge" and not M.resolveUplinks(ifname) then
        return false, T"Select a physical WAN interface first"
    end
    return proxy.set({[wan .. "proto"] = mode, [wan .. "ifname"] = ifname})
end

-- Broadband operations retain their firmware-specific port setup, then move
-- the bridge to the newly selected uplink if a bridge is already active.
function M.changeUplink(operation)
    if get(sensing) == "1" then return false, T"Disable WanSensing before selecting a WAN interface" end
    local bridged = M.isBridged()
    local previous = M.resolveUplinks(M.getUplink())
    if bridged and not previous then
        return false, T"Unable to identify the existing bridge WAN interface; restore its physical uplink first"
    end
    local localConnection = get(wan .. "ifname") == "br-lan"
    local ok, err = operation()
    if ok == false then return false, err end
    if bridged then
        local ifname = get(wan .. "ifname")
        if localConnection then
            ok, err = proxy.set(wan .. "ifname", "br-lan")
            if not ok then return false, err end
        end
        return M.setUplink(ifname, previous)
    end
    return true
end

return M
