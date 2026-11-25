local ipairs, string = ipairs, string
local format = string.format
local proxy = require("datamodel")
local frequency = {}
local M = {}

local function getValue(path)
  local result = proxy.get(path)
  return result and result[1] and result[1].value or ""
end

local function getFrequencyBand(v)
  if frequency[v] then
    return frequency[v]
  end
  local path = format("rpc.wireless.radio.@%s.supported_frequency_bands",v)
  local radio = getValue(path)
  -- Missing radio data can be transient while the wireless backend recovers.
  -- Do not keep an empty result for the lifetime of the nginx worker.
  if radio ~= "" then
    frequency[v] = radio
  end
  return radio
end

-- The EasyMesh backhaul SSID belongs to the controller, not to the user's
-- networks. Its flags are read in the same batched request as the label.
local function getFlagPaths(path)
  local iface = path:match("%.@([^%.]+)%.$")
  if not iface or not iface:match("^[%w_%-]+$") then return nil end
  local base = "uci.wireless.wifi-iface.@" .. iface .. "."
  return base .. "backhaul", base .. "fronthaul"
end

function M.getSSID()
  local ssid_list = {}
  for _, v in ipairs(proxy.getPN("rpc.wireless.ssid.", true) or {}) do
    local path = v.path
    local backhaulPath, fronthaulPath = getFlagPaths(path)
    local values
    if backhaulPath then
      values = proxy.get(path .. "radio", path .. "ssid", path .. "oper_state",
                         path .. "ap_display_name", path .. "stb",
                         backhaulPath, fronthaulPath)
    end
    -- Older firmware may omit the optional label or flag parameters.
    if not values then
      values = proxy.get(path .. "radio", path .. "ssid", path .. "oper_state",
                         path .. "ap_display_name", path .. "stb")
    end
    if not values then
      values = proxy.get(path .. "radio", path .. "ssid", path .. "oper_state")
    end
    local backhaulOnly = values and values[6] and values[6].value == "1" and
                         not (values[7] and values[7].value == "1")
    if values and values[1] and values[2] and values[3] and not backhaulOnly then
      local ap_display_name = values[4] and values[4].value or getValue(path .. "ap_display_name")
      local display_ssid
      if ap_display_name ~= "" then
        display_ssid = ap_display_name
      elseif (values[5] and values[5].value or getValue(path .. "stb")) == "1" then
        display_ssid = "IPTV"
      else
        display_ssid = values[2].value
      end
      ssid_list[#ssid_list+1] = {
        radio = getFrequencyBand(values[1].value),
        ssid = display_ssid,
        state = values[3].value,
      }
    end
  end
  return ssid_list
end

return M
