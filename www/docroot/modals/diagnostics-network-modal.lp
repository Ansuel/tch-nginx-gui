--pretranslated: do not change this file

--NG-96253 GPON-Diagnostics/Network needs to be lifted to TI specific functionalities
--NG-102545 GUI broadband is showing SFP Broadband GUI page when Ethernet 4 is connected
-- Localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local ipairs = ipairs
local match, format = string.match, string.format

local ports = {"eth0", "eth1", "eth2", "eth3"}
local first_column_txt = {"Port 1", "Port 2", "Port 3", "Port 4"}

-- resetting traffic counters button
local clear_network_stats = {
    controls = {
      class = "clear_network_stats"
    },
    button = {
      ["data-name"] = "stats_reset",
      ["data-value"] = "RESET"
    }
}

local isEth4Included = false
if proxy.get("uci.env.rip.sfp")[1].value ~= "1" then
	if proxy.getPN("sys.class.net.@eth4.", true) then
		ports[#ports+1] = "eth4"
		first_column_txt[#first_column_txt+1] = "Port 5"
		isEth4Included = true
	end
else
	if proxy.get("uci.ethernet.globals.eth4lanwanmode")[1].value == "0" then
		ports[4] = "eth4"
		isEth4Included = true
	end
		ports[#ports+1] = "gpon"
		first_column_txt[#first_column_txt+1] = "GPON"
end
local eth = {}
for k,v in ipairs(ports) do
	if v == "gpon" then
		local base_path = "rpc.optical.Interface.1."
		eth["op" .. v] = base_path .. "Status"
		eth["sp" .. v] = base_path .. "OpticalSignalLevel"
	else
		local base_path = "sys.class.net.@" .. v
		eth["op" .. v] = base_path .. ".operstate"
		eth["sp" .. v] = base_path .. ".speed"
	end
end
content_helper.getExactContent(eth)

local ports_speed = {}
local speed = proxy.get("sys.eth.port.")
for _,f in ipairs(speed) do
  if f["param"] == "speed"  and f["value"] ~= "" then
     ports_speed [match(f["path"], "sys.eth.port.@(eth%d)")] = f["value"]
  end
end

local portAttr = {
    socket = {
        class = "socket-form"
    }
}

ngx.print(ui_helper.createHeader(T"Diagnostics", false, false, 2))
ngx.print('<div class="modal-body update">')

    local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-diagnostics.lp")


-- dummy form so that refresh button knows which page to reload, keep it
ngx.print('\
  <form class="form-horizontal" method="post" action="modals/diagnostics-network-modal.lp">\
  </form>\
  <fieldset id="diagnostics-network-tab">\
    <legend>'); ngx.print(T"Ports State"); ngx.print('</legend>\
    <div class="control-group">\
      <label class="control-label">'); ngx.print(T"Type supported"); ngx.print('</label>\
      <div class="controls">')
        for k,v in ipairs(ports) do
          ngx.print('<div class="span2 simple-desc">')
          
            if isEth4Included and match(v, "eth") and proxy.get("uci.ethernet.port.@"..v..".wan")[1].value == "1" then
					portAttr.socket.class = "red socket-form"
			elseif match(v, "gpon") then
					portAttr.socket.class = "red socket-form"
			else
					portAttr.socket.class = "yellow socket-form"
            end
            ngx.print(ui_helper.createSwitchPort(tostring(k), eth["op" .. v], eth["sp" .. v], portAttr))
            -- todo replace speed with actual speed
            if eth["op" .. v] == "up" then
          
              ngx.print('<p class="socket-legend" id = "<%=v%>">'); ngx.print(T"Connected"); ngx.print('<\p>')
              if(ports_speed[v]) then
                ngx.print('<p class="socket-legend">'); ngx.print(format(T"%s Mbps", ports_speed[v])); ngx.print('</legend>')
              end
			elseif eth["op" .. v] == "OPERATION (05)" then
			  ngx.print('<p class="socket-legend" id = "<%=v%>">'); ngx.print(T"Connected-SFP"); ngx.print('<\p>')
              if(ports_speed[v]) then
                ngx.print('<p class="socket-legend">'); ngx.print(format(T"%s Mbps", ports_speed[v])); ngx.print('</legend>')
              end
            else
              ngx.print('<p class="socket-legend grayLight" id = "<%=v%>">'); ngx.print(T"Not connected"); ngx.print('<\p>')
            end
          ngx.print('</div>')
        end
      ngx.print('</div>\
    </div>\
    <legend>'); ngx.print(T"Network Statistics"); ngx.print('</legend>')
    
	local wireless = proxy.get("rpc.wireless.ssid.")
	local wirelessindex = content_helper.convertResultToObject("rpc.wireless.ssid.@.",wireless)
	for i,v in ipairs(wirelessindex) do
		ports[#ports+1] = v.paramindex
		if string.match(v.paramindex, "wl0") then
		first_column_txt[#first_column_txt+1] = v.ssid.."(2,4GHz)"
		else
		first_column_txt[#first_column_txt+1] = v.ssid.."(5GHz)"
		end
	end
	
local post_content
if ngx.var.request_method == "POST" then
    post_content = ngx.req.get_post_args()
    local base_path
    if post_content["stats_reset"] == "RESET" then
      for k,v in ipairs(ports) do
	  if string.match(v, "wl") then
		base_path = "rpc.wireless.ssid.@"..v..".stats.reset"
		elseif match(v, "gpon") then
		base_path = "rpc.optical.Interface.1.Stats.reset"
		else
		base_path = "sys.class.net.@"..v..".statistics.reset"
		end
        proxy.set(base_path, "true")
      end
    end
	local action = ngx.req.get_post_args().action
	for i,v in ipairs(ports) do
			if action == v and string.match(v,"eth") then
			local success = proxy.set("sys.class.net.@"..v..".statistics.reset", "1")
				if success then
					proxy.apply();
				end
			elseif action == v and string.match(v,"wl") then
				local success = proxy.set("rpc.wireless.ssid.@"..v..".stats.reset", "1")
				if success then
					proxy.apply();
				end
			elseif action == v and string.match(v,"gpon") then
				local success = proxy.set("rpc.optical.Interface.1.Stats.reset", "1")
				if success then
					proxy.apply();
				end
			elseif action == "resetall" then
				for x,y in ipairs(ports) do
					if string.match(y, "wl") then
						proxy.set("rpc.wireless.ssid.@"..y..".stats.reset", "1")
					elseif match(y, "eth") then
						proxy.set("sys.class.net.@"..y..".statistics.reset", "1")
					elseif match(y, "gpon") then
						proxy.set("rpc.optical.Interface.1.Stats.reset", "1")
					end
				end
			proxy.apply();
			end
		end
end
	
    local base_path
    local param = {"rx_bytes", "rx_bytes", "tx_bytes", "rx_packets", "tx_packets", "rx_errors", "tx_errors"}
	local gpon_param = {"BytesReceived", "BytesReceived", "BytesSent", "PacketsReceived", "PacketsSent", "ErrorsReceived", "ErrorsSent"}
    local datarows ={}
    for k,v in ipairs(ports) do
      datarows[k]={}
      if string.match(v, "wl") then
        base_path = "rpc.wireless.ssid.@" .. v ..".stats."
	  elseif match(v, "gpon") then
		base_path = "rpc.optical.Interface.1.Stats."
      else
        base_path = "sys.class.net.@" .. v .. ".statistics."
      end
	  if match(v, "gpon") then
		for kk,vv in ipairs(gpon_param) do
			datarows[k][kk] = base_path .. vv
		end
	  else
		  for kk,vv in ipairs(param) do
			datarows[k][kk] = base_path .. vv
		  end
	  end
      content_helper.getExactContent(datarows[k])
	  datarows[k][8] = ui_helper.createSimpleButton(T"Reset Stats", nil, {controls = {class = string.format("clear_network_stats_%s",v)}, button = {["data-name"] = "action", ["data-value"] = string.format("%s",v),}})
    end

    --re-write the first column
    for k,v in ipairs(first_column_txt) do
      datarows[k][1] = v
    end

    local full_array={}
    for i=1, 7 do
      full_array[i]={}
        for z=1, 7 do
          full_array[i][z]="data"..z
        end
     end

    --Column Names
    local columns ={}
    for i=1, 8 do
       columns[i]={}
    end
    columns[1]["header"] = T"Interface"
    columns[2]["header"] = T"Rx Bytes"
    columns[3]["header"] = T"Tx Bytes"
    columns[4]["header"] = T"Rx Packets"
    columns[5]["header"] = T"Tx Packets"
    columns[6]["header"] = T"Rx Errors"
    columns[7]["header"] = T"Tx Errors"
	columns[8]["header"] = T"Reset"
    local options = { tableid = "networkstats", canEdit = false, canAdd = false, canDelete = false }
    -- table that shows the Statistics data
    ngx.print(ui_helper.createTable(columns, datarows, options))
    
    ngx.print('<center>')
      ngx.print(ui_helper.createSimpleButton(T"Reset Stats", "icon-bolt", clear_network_stats))
    ngx.print('</center>\
  </fieldset>\
</div>')
ngx.print(ui_helper.createFooter())
