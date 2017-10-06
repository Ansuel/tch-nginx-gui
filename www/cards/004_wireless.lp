<%
-- Enable localization
--NG-70798
-- NG-92675 implement changes required from the customer
gettext.textdomain('webui-core')

local format = string.format
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local ipairs, ngx, type = ipairs, ngx, type

local function getFrequencyBand(v)
  local path = format("rpc.wireless.radio.@%s.supported_frequency_bands",v)
  local radio = proxy.get(path)[1].value
  return radio
end

local ssid_list = content_helper.convertResultToObject("uci.wireless.wifi-iface.",proxy.get("uci.wireless.wifi-iface."))
local network_map = {}
for _,v in ipairs(ssid_list) do
  network_map[format("%s%s",v.paramindex, v.ssid)] = v.network
end

local ap_paths={true}
local ap_list = proxy.getPN("rpc.wireless.ap.", true)
if type(ap_list) == "table" then
  for i,v in ipairs(ap_list) do
    ap_paths[i] = v.path.."ssid"
  end
end

local wl_list = proxy.get(unpack(ap_paths))
ssid_list = {}
if type(wl_list) == "table" then
  for i,v in ipairs(wl_list) do
    local path = "rpc.wireless.ssid.@" .. v.value
    local values = proxy.get(path .. ".radio" , path .. ".ssid", path .. ".oper_state", path .. ".lan")
    if values and values[4].value == "1" then
      local index = format("@%s%s",v.value, values[2].value)
      -- In cards it should display only the Main SSID and TG-234 SSID's Fix for NG-43454
      if network_map[index] == "lan" or network_map[index] then
        ssid_list[#ssid_list+1] = {
        radio = getFrequencyBand(values[1].value),
        ssid = values[2].value,
        state = values[3].value,
      }
      end
    end
  end
end
--[[table.sort(ssid_list, function(a,b)
	
  return a.wlvalue < b.wlvalue
end)]]
local modalPath
local session = ngx.ctx.session
if session:hasAccess("/modals/wireless-modal.lp") then
  modalPath = "/modals/wireless-modal.lp"
end
%>

<div class="span3">
  <div class="smallcard">
    <%=ui_helper.createCardHeader(T"Wireless", modalPath, nil, nil) %>
    <div class="content card_bg" data-bg-text="&#xf1eb;">
	<div class="divtable">
<%
	
for i,v in pairs(ssid_list) do
  if i <= 4 then
    local status = "light off"
    if(v.state == "1") then
      status = "light green"
    end%>
  <div class="<%=status%>"></div>
    <p class="wifi-card"><strong><%=v.ssid%></strong>(<%=v.radio%>)</p>
  <%else%>
    <p class="wifi-card"><strong style="margin-left:26px;font-size:30px;">...</strong></p>
  <%end
end%>
	  </div>
    </div>
  </div>
</div>
