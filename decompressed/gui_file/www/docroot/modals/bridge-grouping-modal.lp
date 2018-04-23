--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local proxy = require("datamodel")
local lp = require("web.lp")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local message_helper = require("web.uimessage_helper")
local tblremove, tblsort = table.remove, table.sort
local find, gmatch, untaint, format, upper = string.find, string.gmatch, string.untaint, string.format, string.upper

local lanintfs = {
  {"eth0", T"eth0"},
  {"eth1", T"eth1"},
  {"eth2", T"eth2"},
  {"eth3", T"eth3"},
  {"wl0", T"wl0"},
}
local wanintfs_name = {
  wan = T"WAN(default)",
  voip = T"WAN(voip)",
  wan1 = T"WAN1",
  wan2 = T"WAN2",
  wan3 = T"WAN3",
  wan4 = T"WAN4"
}

local wanintfs = {
}

local wl1_path = "uci.wireless.wifi-iface.@wl1.network"
local result = proxy.get(wl1_path)
if type(result) == "table" then
  lanintfs[#lanintfs + 1] = {"wl1", T"wl1"} 
end

local wan_filter = {
  type = "wan",
  available = "1",
}
local wanIntfNames = content_helper.getMatchedContent ("rpc.network.interface.", wan_filter)
local pattern = "rpc.network.interface.@(.*)."
local tmp_tbl = {}
for _, v in pairs(wanIntfNames) do
    local name = v.path:match(pattern)
    if name ~= "wan6" and name ~= "wwan" then
      tmp_tbl[#tmp_tbl + 1] = name
    end
end
tblsort(tmp_tbl)
-- get intf* vlan id
local map_options = {
}
for k, v in pairs(tmp_tbl) do
  if find(v, "intf") then
    map_options[v.."vlan"] = format("uci.network.device.@vlan%s.vid", v:match("intf(%d)"))
  else
    map_options[v.."ifname"] = format("uci.network.interface.@%s.ifname", v)
  end
end
local getContent = {}
for k,v in pairs(map_options) do
  getContent[k] = v
end
local success, errmsg = content_helper.getExactContent(getContent)
if success then
  for k, v in pairs(tmp_tbl) do
   local index = #wanintfs + 1
   if find(v, "intf") then
--      wanintfs[index] = {v, format("%s-VLAN%s", wanintfs_name[v], getContent[v.."vlan"])}
      wanintfs[index] = {v, format("%s", wanintfs_name[v])}
   else
      if find(getContent[v.."ifname"], "eth") then
        wanintfs[index] = {v, format("%s-%s", wanintfs_name[v], upper(getContent[v.."ifname"]))}
      else
        local wanintf_path = format("%s@%s.vid", "uci.network.device.", getContent[v.."ifname"])
        local result = proxy.get(wanintf_path)
        if type(result) == "table" then
--          wanintfs[index] = {v,format("%s-VLAN%s", wanintfs_name[v], result[1]["value"])}
          wanintfs[index] = {v,format("%s", wanintfs_name[v])}
        end
      end
   end
  end
end

local bridge_columns ={
  {
    header = T"Name",
    name = "paramindex",
    param = "paramindex",
    type = "text",
    readonly = "true",
    attr = {input = {class = "span2"}},
  },
  {
    header = T"",
    name = "type",
    param = "type",
    type = "hidden",
    readonly = "true",
    attr = {input = {class = "span2"}},
  },
  {
    header = T"LAN interface",
    name = "lanintf",
    param = "ifname",
    type = "text",
    readonly = "true",
    attr = {input = {class = "span2"}},
  },
  {
    header = T"WAN interface",
    name = "wanintf",
    param = "device",
    type = "text",
    readonly = "true",
    attr = {input = {class = "span2"}},
  },
  {
    header = T"",
    legend = "Layer 2 Bridging",
    name = "bridge",
    param = "bridge",
    type = "aggregate",
    subcolumns = {
      {
        header = T"Name",
        name = "paramindex",
        param = "paramindex",
        type = "text",
        readonly = true,
        attr = {input = {class = "span2", id = "paramindex"}},
      },
      {
        header = T"LAN interface",
        name = "lanintf",
        param = "ifname",
        type = "checkboxgroup",
        values = lanintfs,
        attr = {checkbox = {class = "inline"}},
      },
      {
        header = T"WAN interface",
        name = "wanintf",
        param = "device",
        type = "checkboxgroup",
        values = wanintfs,
        attr = {checkbox = {class = "inline"}},
      },
    },
  },
}
local function tabletostring(tbl)
  local tblvalue = ""
  if "table" == type(tbl) then
    for k,v in pairs(tbl) do
      if v ~= nil and v ~= "" then
        tblvalue = format("%s %s", tblvalue, v)
      end
    end
  end
  return tblvalue
end

local function validateLANIfname(value, object, key)
    local lanvalue = tabletostring(object["lanintf"])
    local wanvalue = tabletostring(object["wanintf"])
    object["lanintf"] = format("%s %s", tabletostring(object["lanintf"]), tabletostring(object["wanintf"]))
    return true
end

local function validateWANIfname(value, object, key)
    object["wanintf"] = ""
    return true
end
local bridge_validate = {
  lanintf = validateLANIfname,
  wanintf = validateWANIfname,
}
local function setOtherBridges(content)
  local post_args = ngx.req.get_post_args()
  local pathvalues={}
  --after add a intf in a new bridge, need to move this intf out of the old bridge
  local bridge_filter = {
    type = "bridge",
  }
  local bridges = content_helper.getMatchedContent ("uci.network.interface.", bridge_filter)
  local modify_path = format("uci.network.interface.@%s.", post_args["paramindex"])
  for k, v in pairs(bridges) do
    local tmp_ifvalue = v.ifname
    if v.path ~= modify_path then
      for w in gmatch(content["lanintf"], "%S+") do
          tmp_ifvalue = tmp_ifvalue:gsub(w, "")
      end
      pathvalues[v.path.."ifname"] = tmp_ifvalue
    end
  end
  if find(content["lanintf"], "wl0") then
    pathvalues["uci.wireless.wifi-iface.@wl0.network"] = post_args["paramindex"]
  elseif find(content["lanintf"], "wl1") then
    pathvalues["uci.wireless.wifi-iface.@wl1.network"] = post_args["paramindex"]
  end
  return pathvalues
end

local function onModify(index, content)
  --after add a intf in a new bridge, need to move this intf out of the old bridge
  local pathvalues = setOtherBridges(content)
  proxy.set(pathvalues)
end
local function onAdd(success, content)
  if success then
    local post_args = ngx.req.get_post_args()
    local pathvalues= setOtherBridges(content)
    local object_path = format("uci.network.interface.@%s.", post_args["paramindex"])
    pathvalues[object_path.."type"] = "bridge"
    pathvalues[object_path.."proto"] = "static"
    success = proxy.set(pathvalues)
  end
end
local bridge_options = {
  canEdit = true,
  canAdd = true,
  canDelete = true,
  tableid = "bridges",
  basepath = "uci.network.interface.@.",
  createMsg = T"Add new bridge",
  addNamedObject = true,
  maxEntries = 5,
  onModify = onModify,
  onAdd = onAdd,
}
local bridge_filter = function(data)
  if data["type"] == "bridge" then
    return true
  end
  return false
end

local bridge_data, bridge_helpmsg = post_helper.handleTableQuery(bridge_columns, bridge_options, bridge_filter, nil, bridge_validate)
local function getIntfName(intf)
  local returnval = ""
  if intf == "wan1" then
    returnval = wanintfs[1][2]
  elseif intf == "wan2" then
    returnval = wanintfs[2][2]
  elseif intf == "wan3" then
    returnval = wanintfs[3][2]
  elseif intf == "wan4" then
    returnval = wanintfs[4][2]
  elseif intf == "voip" then
    returnval = wanintfs[#wanintfs - 1][2]
  elseif intf == "wan" then
    returnval = wanintfs[#wanintfs][2]
  end
  return returnval
end

local lanintf_num, wanintf_num = 3, 4
for _, v in pairs(bridge_data) do
  local lanintf, wanintf = "", ""
  if v[lanintf_num] ~= "" then
    for w in gmatch(v[lanintf_num], "%S+") do
       w = untaint(w)
       if find(w, "^eth") or find(w, "^wl") then
          lanintf = format("%s&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;%s", lanintf, w)
       else
          w = getIntfName(w)
          wanintf = format("%s&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;%s", wanintf, w)
       end
    end
  end
  v[lanintf_num] = lanintf
  v[wanintf_num] = wanintf
end


  ngx.print('\
');  ngx.print(ui_helper.createHeader(T"Layer 2 Bridging", false, true))   ngx.print('\
\
<div class="modal-body update">\
');  
    local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-internet.lp")
  ngx.print('\
<form class="form-horizontal" method="post" action="modals/bridge-grouping-modal.lp">\
');  
  ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
\
<fieldset>\
<legend>');  ngx.print( T"Bridges" ); ngx.print('</legend>\
');  
  ngx.print(ui_helper.createTable(bridge_columns, bridge_data, bridge_options, nil, bridge_helpmsg))
  ngx.print('\
</fieldset>\
</form>\
</div>\
\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
\
\
<script>\
  $(function(){\
    var applyBtn = $("div").hasClass("btn-table-modify");\
    if (applyBtn == true) {\
      $("#paramindex").parent().parent().hide();\
    }\
  });\
</script>\
'); 