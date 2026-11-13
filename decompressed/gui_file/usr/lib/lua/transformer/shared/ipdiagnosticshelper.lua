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

-- Used by /usr/bin/ipping and /usr/bin/igd_traceroute (firmware 19.x).
-- Copies the command output to tmp_file while it is produced (GUI polling)
-- and returns the full output.
function M.copy_ping_or_traceroute_result(user, fp, tmp_file)
  local output
  if user == "diagping" or user == "webui" then
    local tmp_fp = io.open(tmp_file, "w")
    if not tmp_fp then
      return
    end
    for line in fp:lines() do
      tmp_fp:write(line .. '\n')
      tmp_fp:flush()
      output = output and output .. line .. '\r\n' or line .. '\r\n'
    end
    tmp_fp:close()
  else
    output = fp:read("*a")
  end
  return output
end

return M
