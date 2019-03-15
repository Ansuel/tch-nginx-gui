--pretranslated: do not change this file
 
-- Enable localization
-- NG-70798 [GUI] Guest SSID are not shown on Wireless Card
-- NG-92675 implement changes required from the customer
gettext.textdomain('webui-core')

local ipairs, ngx, string = ipairs, ngx, string
local format, match = string.format, string.match
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local attributes = { light = { } ,span = { class = "span4" } }
local frequency = {}
local function getFrequencyBand(v)
  if frequency[v] then
    return frequency[v]
  end
  local path = format("rpc.wireless.radio.@%s.supported_frequency_bands",v)
  local radio = proxy.get(path)[1].value
  frequency[v] = radio
  return radio
end
local function displayOnCard(index)
  return not index or match(index,"[l|w]an") or match(index, "^VLAN%d$")
end

local ssid_list = content_helper.convertResultToObject("uci.wireless.wifi-iface.",proxy.get("uci.wireless.wifi-iface."))
local network_map = {}
for _,v in ipairs(ssid_list) do
  network_map[format("%s%s",v.paramindex, v.ssid)] = v.network
end

ssid_list = {}
ssid_list_guest = {}
 for _, v in ipairs(proxy.getPN("rpc.wireless.ssid.", true)) do
  local path = v.path
  local values = proxy.get(path .. "radio" , path .. "ssid", path .. "oper_state")
  if values then
    local index = format("@%s%s", match(path, "rpc.wireless.ssid.@([%w%_]+)."), values[2].value)
	local intf = format("@%s", match(path, "rpc.wireless.ssid.@([%w%_]+)."))
    -- In cards it should display only the Main SSID and TG-234 SSID's Fix for NG-43454
    --if displayOnCard(network_map[index]) then
      local ap_display_name = proxy.get(path .. "ap_display_name")[1].value
      local display_ssid
      if ap_display_name ~= "" then
        display_ssid = ap_display_name
      elseif proxy.get(path .. "stb")[1].value == "1" then
        display_ssid = "IPTV"
      else
        display_ssid = values[2].value
      end
	  if intf == "@wl0" or intf == "@wl1" then
		ssid_list[#ssid_list+1] = {
		intf = intf,
		radio = getFrequencyBand(values[1].value),
		ssid = display_ssid,
		state = values[3].value,
		}
	  end
	  if intf == "@wl0_1" or intf == "@wl1_1" then
		ssid_list_guest[#ssid_list_guest+1] = {
		intf = intf,
		radio = getFrequencyBand(values[1].value),
		ssid = display_ssid,
		state = values[3].value,
		}
	  end
    --end
  end
end
table.sort(ssid_list, function(a,b)
  return a.intf < b.intf
end)
table.sort(ssid_list_guest, function(a,b)
  return a.intf < b.intf
end)
local modalPath
local session = ngx.ctx.session
if session:hasAccess("/modals/wireless-modal.lp") then
  modalPath = "/modals/wireless-modal.lp"
end
  ngx.print('\
\
<div class="span3">\
  <div class="smallcard" data-aos="zoom-in" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\
    ');  ngx.print(ui_helper.createCardHeader(T"Wireless", modalPath, nil, nil) ); ngx.print('\
    <div class="content card_bg" data-bg-text="&#xf1eb;">\
	<div class="divtable">\
');  
	local html = {}
for i,v in pairs(ssid_list) do
  local wifi_text = '<strong style="margin-left:26px;font-size:30px;">...</strong>'
  if i <= 4 then
	wifi_text = format('<strong>%s</strong>(%s)',v.ssid or nil ,v.radio or nil)
  end
  attributes.light.id = "WiFi_Enabled_Led"
	attributes.span.id = "WiFi_Enabled"
   html[#html+1] = ui_helper.createSimpleLight(v.state or "0", wifi_text, attributes,"fa fa-wifi")
end
for i,v in pairs(ssid_list_guest) do
  local wifi_text = '<strong style="margin-left:26px;font-size:30px;">...</strong>'
  if i <= 4 then
	wifi_text = format('<strong>%s</strong>(%s)',v.ssid or nil ,v.radio or nil)
  end
  attributes.light.id = "WiFi_Guest_Enabled_Led"
	attributes.span.id = "WiFi_Guest_Enabled"
   html[#html+1] = ui_helper.createSimpleLight(v.state or "0", wifi_text, attributes,"fa fa-wifi")
end  
	ngx.print(html)
	ngx.print('\
	</div>\
    </div>\
  </div>\
</div>\
'); 