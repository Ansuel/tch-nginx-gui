--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local internet = require("internethelper")
local ipairs = ipairs
local match, format, lower = string.match, string.format, string.lower

local function getValue(path)
  local result = proxy.get(path)
  return result and result[1] and result[1].value or ""
end

local function hasPath(path)
  local result = proxy.get(path)
  return result and result[1] ~= nil
end

local ports = {"eth0", "eth1", "eth2", "eth3"}
local first_column_txt = {T"Port 1", T"Port 2", T"Port 3", T"Port 4"}

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
local sfp_enabled = getValue("uci.env.rip.sfp") == "1"
local ok_bh, bridgehelper = pcall(require, "bridgehelper")
local ok_gpon, is_gpon = pcall(ok_bh and bridgehelper and bridgehelper.hasIntegratedGpon or function() return false end)
local integrated_gpon = ok_gpon and is_gpon or false
local has_gpon = integrated_gpon or hasPath("rpc.optical.Interface.1.Status") or hasPath("rpc.gpon.ploam.state")
if not sfp_enabled then
  local eth4 = proxy.getPN("sys.class.net.@eth4.", true)
  if eth4 and next(eth4) then
    ports[#ports+1] = "eth4"
    first_column_txt[#first_column_txt+1] = "Port 5"
    isEth4Included = true
  end
else
  if getValue("uci.ethernet.globals.eth4lanwanmode") == "0" then
    ports[4] = "eth4"
    isEth4Included = true
  end
end
if sfp_enabled or has_gpon then
  ports[#ports+1] = "gpon"
  first_column_txt[#first_column_txt+1] = "GPON"
end
local eth = {}
for k,v in ipairs(ports) do
  if v == "gpon" then
    if integrated_gpon then
      eth.opgpon = "rpc.gpon.ploam.state"
    else
      eth.opgpon = "rpc.optical.Interface.1.Status"
      eth.spgpon = "rpc.optical.Interface.1.OpticalSignalLevel"
    end
  else
    local base_path = "sys.class.net.@" .. v
    eth["op" .. v] = base_path .. ".operstate"
    eth["sp" .. v] = base_path .. ".speed"
  end
end
internet.getOptionalContent(eth)
local gpon_status = eth.opgpon
if integrated_gpon and gpon_status then
  if gpon_status == "OPERATION" or gpon_status == "O5" then eth.opgpon = "up" end
end

local ports_speed = {}
local speed = proxy.get("sys.eth.port.") or {}
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
  ngx.print('\
');  ngx.print(ui_helper.createHeader(T"Diagnostics", false, false, 2) ); ngx.print('\
<div class="modal-body update">\
');  
  local lp = require("web.lp")
  lp.setpath("/www/snippets/")
  lp.include("tabs-diagnostics.lp")
  ngx.print('\
');  
-- dummy form so that refresh button knows which page to reload, keep it
  ngx.print('\
  <form class="form-horizontal" method="post" action="modals/diagnostics-network-modal.lp">\
  </form>\
  <fieldset id="diagnostics-network-tab">\
	<fieldset>\
	<legend>');  ngx.print( T"Ports State" ); ngx.print('</legend>\
	<div class="control-group">\
      <div class="controls">\
      ');  for k, v in ipairs(ports) do  ngx.print('\
        <div class="span2 simple-desc">\
        ');  
          if isEth4Included and match(v, "eth") and getValue("uci.ethernet.port.@"..v..".wan") == "1" then
	    portAttr.socket.class = "red socket-form"
	  elseif match(v, "gpon") then
	    portAttr.socket.class = "red socket-form"
	  else
	    portAttr.socket.class = "yellow socket-form"
          end
          ngx.print(ui_helper.createSwitchPort(tostring(k), lower(eth["op" .. v] or ""), eth["sp" .. v], portAttr))
          -- todo replace speed with actual speed
          if eth["op" .. v] == "up" then
	    ngx.print('\
	    <p class="socket-legend" id = "');  ngx.print(v); ngx.print('">');  ngx.print( T"Connected" ); ngx.print('<p>\
            ');  if(ports_speed[v]) then  ngx.print('\
              <p class="socket-legend">(');  ngx.print(format(T"%s Mbps", ports_speed[v]) ); ngx.print(')</legend>\
            ');  end  ngx.print('\
	    ');  elseif eth["op" .. v] == "Up" then  ngx.print('\
              <p class="socket-legend" id = "');  ngx.print(v); ngx.print('">');  ngx.print( T"Connected-SFP" ); ngx.print('<p>\
              ');  if(ports_speed[v]) then  ngx.print('\
                <p class="socket-legend">(');  ngx.print( format(T"%s Mbps", ports_speed[v]) ); ngx.print(')</legend>\
            ');  end   ngx.print('\
            ');  elseif v == "gpon" and integrated_gpon and gpon_status == "" then
              ngx.print('<p class="socket-legend grayLight">', T"Unavailable", '</p>')
            else   ngx.print('\
              <p class="socket-legend grayLight" id = "');  ngx.print(v); ngx.print('">');  ngx.print( T"Not connected" ); ngx.print('<p>\
            ');  end   ngx.print('\
          </div>\
        ');  end   ngx.print('\
      </div>\
    </div>\
	</fieldset>\
	<fieldset>\
    <legend class="networkStat">');  ngx.print( T"Network Statistics" ); ngx.print('</legend>\
    ');  
      local wireless = proxy.get("rpc.wireless.ssid.") or {}
      local wirelessindex = content_helper.convertResultToObject("rpc.wireless.ssid.@.",wireless) or {}
      for _,v in ipairs(wirelessindex) do
        local iface = string.untaint and string.untaint(v.paramindex) or v.paramindex
        local radio = v.radio and (string.untaint and string.untaint(v.radio) or v.radio) or ""
        ports[#ports+1] = iface
        local band = radio ~= "" and getValue("rpc.wireless.radio.@" .. radio .. ".supported_frequency_bands") or ""
        local band_label = band ~= "" and (" (" .. band .. ")") or ""
        local ssid_name = (v.ssid and v.ssid ~= "") and v.ssid or iface
        first_column_txt[#first_column_txt+1] = ssid_name .. band_label
      end

local function statsPath(port)
  if match(port, "wl") then return "rpc.wireless.ssid.@" .. port .. ".stats." end
  if port == "gpon" then
    return integrated_gpon and "sys.class.net.@gpondef.statistics." or "rpc.optical.Interface.1.Stats."
  end
  return "sys.class.net.@" .. port .. ".statistics."
end

if ngx.var.request_method == "POST" then
  local posted = ngx.req.get_post_args()
  local resetAll = posted.stats_reset == "RESET" or posted.action == "resetall"
  local changed
  for _, port in ipairs(ports) do
    if (resetAll or posted.action == port) and not (port == "gpon" and integrated_gpon) then
      local success = proxy.set(statsPath(port) .. "reset", "1")
      changed = changed or success
    end
  end
  if changed then proxy.apply() end
end

local param = {"rx_bytes", "tx_bytes", "rx_packets", "tx_packets", "rx_errors", "tx_errors"}
local gpon_param = {"BytesReceived", "BytesSent", "PacketsReceived", "PacketsSent", "ErrorsReceived", "ErrorsSent"}
local datarows ={}
for k,v in ipairs(ports) do
  datarows[k]={}
  local base_path = statsPath(v)
  local counters = v == "gpon" and not integrated_gpon and gpon_param or param
  for column, counter in ipairs(counters) do
    datarows[k][column + 1] = base_path .. counter
  end
  internet.getOptionalContent(datarows[k])
  for column = 2, 7 do
    if datarows[k][column] == "" then
      datarows[k][column] = (v == "gpon" and integrated_gpon) and "—" or "0"
    end
  end
  if v == "gpon" and integrated_gpon then
    datarows[k][8] = ""
  else
    datarows[k][8] = ui_helper.createSimpleButton(T"Reset Stats", nil, {controls = {class = string.format("clear_network_stats_%s",v)}, button = {["data-name"] = "action", ["data-value"] = string.format("%s",v),}})
  end
end

  --re-write the first column
  for k,v in ipairs(first_column_txt) do
    if datarows[k] then
      datarows[k][1] = v
    end
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
    ngx.print('\
  <center>\
    ');  ngx.print( ui_helper.createSimpleButton(T"Reset Stats", "icon-bolt", clear_network_stats)); ngx.print('\
  </center>\
  </fieldset>\
  </fieldset>\
</div>\
<script>\
(function() {\
  var st = window._diagNetScroll || { body: 0, modal: 0, win: 0, refreshing: false };\
  window._diagNetScroll = st;\
  var modalBody = $("#diagnostics-network-tab").closest(".modal-body");\
  var modalBox = $("#diagnostics-network-tab").closest(".modal");\
\
  function restoreScroll() {\
    if (modalBody.length) modalBody.scrollTop(st.body);\
    if (modalBox.length) modalBox.scrollTop(st.modal);\
    $(window).scrollTop(st.win);\
  }\
\
  restoreScroll();\
  setTimeout(restoreScroll, 0);\
  setTimeout(function() {\
    restoreScroll();\
    st.refreshing = false;\
  }, 30);\
\
  modalBody.off("scroll.diagKeep").on("scroll.diagKeep", function() {\
    if (!st.refreshing) st.body = $(this).scrollTop();\
  });\
  modalBox.off("scroll.diagKeep").on("scroll.diagKeep", function() {\
    if (!st.refreshing) st.modal = $(this).scrollTop();\
  });\
  $(window).off("scroll.diagKeep").on("scroll.diagKeep", function() {\
    if (!st.refreshing) st.win = $(this).scrollTop();\
  });\
\
  $(document).off("ajaxSend.diagKeep").on("ajaxSend.diagKeep", function(e, xhr, settings) {\
    if (settings && settings.url && settings.url.indexOf("diagnostics-network-modal.lp") !== -1) {\
      st.refreshing = true;\
      if (modalBody.length) st.body = modalBody.scrollTop();\
      if (modalBox.length) st.modal = modalBox.scrollTop();\
      st.win = $(window).scrollTop();\
    }\
  });\
  $(document).off("ajaxError.diagKeep").on("ajaxError.diagKeep", function() {\
    st.refreshing = false;\
  });\
})();\
</script>\
');  ngx.print(ui_helper.createFooter() ); ngx.print('\
');
