
local require = require

local M = {}

local uci_helper = require 'transformer.mapper.ucihelper'
local common = require 'transformer.mapper.nwcommon'
local is_alias=common.is_alias

local network = require 'transformer.shared.common.network'


function M.entries()
  local LANDevices = {}
  local binding = {config="network",sectionname="interface"}
  local wan = network.getWanInterfaces()
  uci_helper.foreach_on_uci(binding, function(s)
  -- iterate over the network interface and take those that have proto set to static
  -- this should identify the LAN interfaces with an IP layer and the odds
  -- we exclude the interface named loopback as it should not be included and will be present in every product
  -- we also exclude all alias interfaces
    if s['.name'] == 'loopback' or is_alias(s['.name']) then
      return
    end
    if wan[s['.name']] then
     return
    end

    if s['proto'] then
      LANDevices[#LANDevices+1] = s['.name']
    end
  end)

  return LANDevices
end

return M
