-- Enable localization
gettext.textdomain('webui-datausage')

local json = require("dkjson")
local proxy = require("datamodel")
local content_helper = require("web.content_helper")

local untaint = string.untaint or function(s) return s end
local post_data = ngx.req.get_post_args()

local function valid_name(name)
  return type(name) == "string" and name:match("^[%w_.%-]+$") ~= nil
end

local function value(path)
  local ok, result = pcall(proxy.get, path)
  return ok and type(result) == "table" and result[1] and result[1].value or nil
end

local function has(v)
  return v ~= nil and v ~= ""
end

-- Interfaccia mostrata sulla card: quella scelta nella modale (se il datamodel
-- espone rpc.datausage_notifier, che su alcuni firmware non c'e'); altrimenti
-- la prima interfaccia abilitata in /etc/config/datausage, altrimenti "wan".
local function selected_interface()
  local selected = value("rpc.datausage_notifier.web_selected_interface")
  if valid_name(selected) then
    return selected
  end
  local ok, info = pcall(proxy.get, "uci.datausage.interface.")
  if ok and type(info) == "table" then
    local list = content_helper.convertResultToObject("uci.datausage.interface.@.", info) or {}
    local first
    for _, item in ipairs(list) do
      local name = has(item.interface) and item.interface or item.paramindex
      if valid_name(name) then
        if item.enabled == "1" then
          return name
        end
        first = first or name
      end
    end
    if first then
      return first
    end
  end
  return "wan"
end

----------------------------------------------------------------------------
-- Piano B: contatori dell'interfaccia (gli stessi del Traffic Monitor).
-- Si usa solo se datausaged/il mapping rpc.datausage non restituiscono dati.
-- Lo stato (ultimo campione e punto di azzeramento) sta in /tmp.
----------------------------------------------------------------------------
local function state_file(iface)
  return "/tmp/gui_datausage_" .. untaint(iface) .. ".state"
end

local function read_state(iface)
  local f = io.open(state_file(iface), "r")
  if not f then return nil end
  local line = f:read("*l")
  f:close()
  local n = {}
  for token in (line or ""):gmatch("%S+") do
    n[#n + 1] = tonumber(token)
  end
  if #n < 7 then return nil end
  return { t = n[1], tx = n[2], rx = n[3], btx = n[4], brx = n[5], txr = n[6], rxr = n[7] }
end

local function write_state(iface, st)
  local f = io.open(state_file(iface), "w")
  if not f then return end
  f:write(string.format("%.3f %.0f %.0f %.0f %.0f %.3f %.3f\n",
    st.t, st.tx, st.rx, st.btx, st.brx, st.txr, st.rxr))
  f:close()
end

local function read_counters(iface)
  local tx = tonumber(value("rpc.network.interface.@" .. iface .. ".tx_bytes"))
  local rx = tonumber(value("rpc.network.interface.@" .. iface .. ".rx_bytes"))
  if tx and rx then
    return tx, rx
  end
  return nil
end

local function fallback_usage(iface)
  local tx, rx = read_counters(iface)
  if not tx then return nil end
  local now = ngx.now()
  local st = read_state(iface)
  if not st or tx < st.tx or rx < st.rx then
    -- primo campione o contatori ripartiti (riavvio): totale dall'inizio dei contatori
    st = { t = now, tx = tx, rx = rx, btx = 0, brx = 0, txr = 0, rxr = 0 }
    write_state(iface, st)
  else
    local dt = now - st.t
    -- campioni ravvicinati (card + modale insieme) riusano l'ultima velocita'
    if dt >= 1 then
      st.txr = (tx - st.tx) / dt
      st.rxr = (rx - st.rx) / dt
      st.t, st.tx, st.rx = now, tx, rx
      write_state(iface, st)
    end
  end
  local txr = math.floor(st.txr)
  local rxr = math.floor(st.rxr)
  return {
    interface = iface,
    enabled = "1",
    tx_bytes_average = txr,
    rx_bytes_average = rxr,
    tx_bytes_per_second = txr,
    rx_bytes_per_second = rxr,
    tx_bytes_total = math.floor(tx - st.btx),
    rx_bytes_total = math.floor(rx - st.brx),
    usage_limit_reached = "false",
    usage_threshold_reached = "false",
    source = "interface-counters"
  }
end

local function fallback_reset(iface)
  local tx, rx = read_counters(iface)
  if tx then
    write_state(iface, { t = ngx.now(), tx = tx, rx = rx, btx = tx, brx = rx, txr = 0, rxr = 0 })
  end
end

local function get_usage(iface)
  local ok, info = pcall(proxy.get, string.format("rpc.datausage.interface.@%s.", iface))
  if ok and type(info) == "table" and #info > 0 then
    local list = content_helper.convertResultToObject("rpc.datausage.interface.@.", info)
    local obj = list and list[1]
    if obj and (has(obj.tx_bytes_total) or has(obj.tx_bytes_average) or has(obj.tx_bytes_per_second)) then
      return obj
    end
  end
  return fallback_usage(iface)
end

if post_data.action == "get" and valid_name(post_data.interface) then
  local usage = get_usage(post_data.interface)
  local buffer = {}
  local ret = json.encode(usage or {}, { indent = false, buffer = buffer })
  if ret then
    ngx.say(buffer)
    ngx.exit(ngx.HTTP_OK)
  end
elseif post_data.action == "reset" and valid_name(post_data.interface) then
  pcall(proxy.set, string.format("rpc.datausage.interface.@%s.reset", post_data.interface), "1")
  fallback_reset(post_data.interface)
elseif post_data.action == "overview" then
  local usage = get_usage(selected_interface()) or {}
  local rx = usage.rx_bytes_per_second or usage.rx_bytes_average
  local tx = usage.tx_bytes_per_second or usage.tx_bytes_average
  ngx.print((has(rx) and rx or "0") .. "," .. (has(tx) and tx or "0"))
  ngx.exit(ngx.HTTP_OK)
end

ngx.say("{}")
ngx.exit(ngx.HTTP_OK)
