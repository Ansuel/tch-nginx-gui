local M = {}

local common = require 'transformer.mapper.nwcommon'
local match, format = string.match, string.format

local function get_src_by_host(host)
    if not match(host, "(%d+%.%d+%.%d+%.%d+)") then
        -- if domain name, resolve to ip address
        local cmdline = host and format("dnsget %s 2>&1", host)
        local p = assert(io.popen(cmdline))
        local resolvedhostname
        for line in p:lines() do
            resolvedhostname = match(line,"([^%s]+)%.%s")
            if resolvedhostname then
                host = match(line,"%s+(%d+%.%d+%.%d+%.%d+)")
                if host then
                    break
                end
            end
        end
        p:close()
    end
    if host then
        -- get interface by route
        local cmdline = format("ip route get %s 2>&1", host)
        local p = assert(io.popen(cmdline))
        local output = p:read("*a")
        p:close()
        return match(output, "src%s+(%d+%.%d+%.%d+%.%d+)")
    end
end

-- convert logical interface to physical
function M.get_physical_interface(interface, host)
  if interface and interface:len() ~= 0 then
    local status = common.get_ubus_interface_status(interface)
    local iface = status and status["l3_device"]
    if not iface then
      return
    end
    local addr = status['ipv4-address'] and status['ipv4-address'][1] and status['ipv4-address'][1]['address']
    return iface, addr
  else
    return "", get_src_by_host(host)
  end
end

return M
