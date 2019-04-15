local ipairs, string = ipairs, string
local format = string.format
local proxy = require("datamodel")
local frequency = {}
local M = {}

local function getFrequencyBand(v)
  if frequency[v] then
    return frequency[v]
  end
  local path = format("rpc.wireless.radio.@%s.supported_frequency_bands",v)
  local radio = proxy.get(path)[1].value
  frequency[v] = radio
  return radio
end

function M.getSSID()
  local ssid_list = {}
  for _, v in ipairs(proxy.getPN("rpc.wireless.ssid.", true)) do
    local path = v.path
    local values = proxy.get(path .. "radio" , path .. "ssid", path .. "oper_state")
    if values then
      local ap_display_name = proxy.get(path .. "ap_display_name")[1].value
      local display_ssid
      if ap_display_name ~= "" then
        display_ssid = ap_display_name
      elseif proxy.get(path .. "stb")[1].value == "1" then
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
