
local M = {}

-- This function returns the USB port number based on a given directory name
-- created in /sys/bus/usb/devices/ when a USB storage device is inserted.
-- Expected input: Directory Name
-- Return value: USB Port Label
function M.get_usb_label(port)
  return port:match('.*%-(%d+)')
end

return M