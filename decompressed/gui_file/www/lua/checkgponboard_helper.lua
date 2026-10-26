local lfs = require("lfs")
local M = {}
function M.isGPONBoard()
    local result = false
    if lfs.attributes("/proc/rip/011b", "mode") == "file" then
	local fd = io.popen("hexdump -n 1 /proc/rip/011b|awk '{print $2}'")
        if fd then
	    for line in fd:lines() do
		local type = string.sub(line, 1,2)
		if type == "01" or type == "02" then
		  result = true
		end
	    end
	     fd:close()
	end
      end
      return result

end

return M
