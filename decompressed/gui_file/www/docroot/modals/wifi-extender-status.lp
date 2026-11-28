--pretranslated: do not change this file
gettext.textdomain('webui-core')
local mesh = require("easymesh_helper")
local ui = require("web.ui_helper")
if not mesh.is_supported() then
  ngx.print(ui.createHeader(T"EasyMesh", false, true))
  ngx.print(ui.createAlertBlock(T"EasyMesh is not available on this device."))
  ngx.print(ui.createFooter())
  return
end

local topology = require("easymesh_topology")
local plain, mac = topology.plain, topology.mac
local escape = require("web.web").html_escape
local proxy = require("datamodel")
local content = require("web.content_helper")
local function text(value) return escape(plain(value)) end
local function value(path)
  local ok, rows = pcall(proxy.get, path)
  return ok and rows and rows[1] and rows[1].value or ""
end
local function objects(path)
  local ok, rows = pcall(proxy.get, path)
  if not ok or type(rows) ~= "table" then return {} end
  local converted, result = pcall(content.convertResultToObject, path, rows)
  return converted and type(result) == "table" and result or {}
end
local count = value("rpc.multiap.ExtenderNumberOfEntries")
if count == "" then
  ngx.print(ui.createHeader(T"EasyMesh", false, true))
  ngx.print(ui.createAlertBlock(T"EasyMesh service is not available."))
  ngx.print(ui.createFooter())
  return
end
local model = plain(value("uci.env.var.prod_friendly_name"))
local root = {type="gateway", model=model, name=plain(value("uci.system.system.@system[0].hostname")),
  macAddr=plain(value("uci.multiap.controller.macaddress")), clients={}}
local agentMAC = plain(value("uci.multiap.agent.macaddress"))
local controller = value("uci.multiap.controller.enabled") == "1"
if not controller then root.macAddr = agentMAC end
if root.name == "" then root.name = model ~= "" and model or T"Gateway" end
root.role = controller and T"Controller" or (value("uci.multiap.agent.enabled") == "1" and T"Agent" or T"Disabled")

local hosts, infra, seen = {}, {}, {}
infra[mac(root.macAddr)], infra[mac(agentMAC)] = true, true
local columns = {}
for _, name in ipairs({"HostName","Speed","IPv4","State","InterfaceType","L2Interface","L3Interface","MACAddress"}) do
  columns[#columns + 1] = {param=name,type="text"}
end
local ok_hosts, rows = pcall(content.loadTableData, "sys.hosts.host.", columns)
for _, host in ipairs(ok_hosts and rows or {}) do
  if plain(host[8]) ~= "" then hosts[mac(host[8])] = host end
end
local agents = {}
for _, node in ipairs(objects("rpc.multiap.device.")) do
  local address = plain(node.al_mac)
  if address ~= "" and mac(address) ~= mac(root.macAddr) and mac(address) ~= mac(agentMAC) then
    local class = plain(node.productclass or node.product_class or node.model_name)
    local name = plain(node.FriendlyName)
    if name == "" then name = plain(node.device_name) end
    if name == "" or name:match("^agent_") then name = class ~= "" and class or T"Extender" end
    agents[#agents + 1] = {type="extender",name=name,model=class,macAddr=address,
      parentAccessPoint=plain(node.parent),connectionType=plain(node.backhaul_interface_type),
      status=plain(node.status),rssi=tonumber(node.rssi),clients={},native=node}
    infra[mac(address)] = true
    for alias in plain(node.local_interfaces):gmatch("%x%x:%x%x:%x%x:%x%x:%x%x:%x%x") do infra[mac(alias)] = true end
  end
end
local stations = {}
for _, station in ipairs(objects("rpc.multiap.sta.")) do stations[mac(station.mac)] = station end
local function add_client(parent, address, kind, station)
  local key = mac(address)
  if key == "" or infra[key] or seen[key] then return end
  local host = hosts[key]
  local name = host and plain(host[1]) or ""
  local client = {type="host", name=name ~= "" and name or plain(address), macAddr=plain(address),
    ipAddress=host and plain(host[3]) or "",connectionType=kind}
  local rate = station and tonumber(station.tx_phy_rate or station.dl_mac_rate)
  if rate then client.speed = rate / 1000 end
  parent.clients[#parent.clients + 1], seen[key] = client, true
end
for _, agent in ipairs(agents) do
  for parameter, list in pairs(agent.native) do
    if type(parameter) == "string" and parameter:match("sta_list$") then
      for address in plain(list):gmatch("%x%x:%x%x:%x%x:%x%x:%x%x:%x%x") do
        local station = stations[mac(address)]
        local owner = station and plain(station.assoc_agent_mac) or ""
        if owner == "" or mac(owner) == mac(agent.macAddr) then add_client(agent,address,T"Wireless",station) end
      end
    end
  end
  for address in plain(agent.native.eth_clients):gmatch("%x%x:%x%x:%x%x:%x%x:%x%x:%x%x") do
    add_client(agent,address,T"Ethernet")
  end
  agent.native = nil
end
-- Newer native mappings expose locally attached Ethernet clients separately.
-- Older firmware can omit this object without hiding the rest of the topology.
for _, client in ipairs(objects("rpc.multiap.eth.")) do
  add_client(root,client.MacAddress,T"Ethernet")
end
local ok_aps, aps = pcall(proxy.getPN,"rpc.wireless.ap.",true)
for _, ap in ipairs(ok_aps and aps or {}) do
  for _, station in ipairs(objects(ap.path .. "station.")) do
    if station.state ~= "Disconnected" and station.state ~= "Authenticated" then
      local address = plain(station.paramindex):gsub("^@", "")
      add_client(root,address,T"Wireless",station)
    end
  end
end
root.children = topology.forest(agents)

ngx.print(ui.createHeader(T"EasyMesh Topology",false,true))
ngx.print('<div class="modal-body update"><form class="form-horizontal" action="/modals/wifi-extender-status.lp">')
local lp = require("web.lp")
lp.setpath("/www/snippets/")
lp.include("tabs-easyMesh.lp")
ngx.print([=[<style>
.mesh-topology {max-width:100%;padding:12px 2px;box-sizing:border-box}
.mesh-topology .mesh-tree {display:table;min-width:100%;margin:0;padding:0}
.mesh-topology ul {margin:0 0 0 24px;padding:12px 0 0 16px;border-left:1px solid rgba(127,127,127,.55)}
.mesh-topology li {list-style:none;position:relative;margin:0 0 12px;padding:0}
.mesh-topology li:before {content:"";position:absolute;left:-16px;top:42px;width:16px;border-top:1px solid rgba(127,127,127,.55)}
.mesh-topology .mesh-tree>li:before {display:none}
.mesh-topology .mesh-node {display:flex;align-items:center;gap:12px;box-sizing:border-box;width:280px;max-width:100%;padding:12px;border:1px solid rgba(127,127,127,.4);border-radius:6px;background:rgba(127,127,127,.12);color:inherit}
.mesh-topology .mesh-picture {width:76px;height:80px;object-fit:contain;flex-shrink:0}
.mesh-topology .mesh-details {min-width:0;overflow-wrap:anywhere;word-wrap:break-word}
.mesh-topology .mesh-details strong,.mesh-topology .mesh-details small {display:block;color:inherit}
.mesh-topology .mesh-details small {font-size:11px;line-height:1.5;opacity:.8}
.mesh-topology .mesh-meta {margin-top:4px}
@media(max-width:480px){.mesh-topology .mesh-node{width:248px}.mesh-topology ul{margin-left:12px;padding-left:12px}.mesh-topology li:before{left:-12px;width:12px}}
</style><div class="mesh-topology"><ul class="mesh-tree">]=])
local function render(node)
  local image = node.type == "host" and "wifi_all.png" or topology.image(node.model,node.type)
  ngx.print('<li><article class="mesh-node"><img class="mesh-picture" src="/img/',text(image),'" alt="',text(node.model ~= "" and node.model or node.type),'">')
  ngx.print('<div class="mesh-details"><strong>',text(node.name),'</strong>')
  if node.model and node.model ~= "" and node.model ~= node.name then ngx.print('<small class="muted">',text(node.model),'</small>') end
  ngx.print('<small>',text(node.macAddr),'</small><div class="mesh-meta">')
  if node.role then ngx.print('<span class="label">',text(node.role),'</span> ') end
  if node.connectionType and node.connectionType ~= "" then ngx.print('<span class="label label-info">',text(node.connectionType),'</span> ') end
  if node.ipAddress and node.ipAddress ~= "" then ngx.print('<small>',text(node.ipAddress),'</small>') end
  if node.rssi and node.connectionType ~= "Ethernet" then ngx.print('<small>RSSI: ',text(node.rssi),' dBm</small>') end
  if node.speed then ngx.print('<small>',text(node.speed),' Mbps</small>') end
  if node.status and node.status ~= "" then ngx.print('<small>',text(node.status),'</small>') end
  ngx.print('</div></div></article>')
  local children = {}
  for _, child in ipairs(node.children or {}) do children[#children + 1] = child end
  for _, client in ipairs(node.clients or {}) do children[#children + 1] = client end
  table.sort(children,function(a,b) return plain(a.name):lower() < plain(b.name):lower() end)
  if #children > 0 then
    ngx.print('<ul>')
    for _, child in ipairs(children) do render(child) end
    ngx.print('</ul>')
  end
  ngx.print('</li>')
end
render(root)
ngx.print('</ul></div>')
if #agents == 0 then ngx.print('<p class="muted">',text(controller and T"No extenders connected" or T"Extender topology is available on the controller."),'</p>') end
lp.include("easymesh-history.lp")
ngx.print('</form></div>',ui.createFooter())
