#!/bin/sh

# Temporary eRIPv2 key extraction with the r2secr module from
# https://github.com/pedro-n-rocha/secr. Runs from the Transformer RPC as a
# background job: the module download must not block the RPC dispatcher.

STATUS_FILE=/tmp/rip_keys_status

case "$1" in
  clear)
    rm -f /tmp/rip_secrets "$STATUS_FILE"
    exit 0
    ;;
  extract)
    lua -e '
      local rip = dofile("/usr/share/transformer/scripts/rip_index.lua")
      local function write_status(state)
        state = tostring(state):gsub("[;\r\n]+", " ")
        local file = io.open("/tmp/rip_keys_status", "wb")
        if file then file:write(state) file:close() end
      end
      local function uname(flag)
        local handle = io.popen("uname -" .. flag)
        local value = handle and handle:read("*l") or ""
        if handle then handle:close() end
        return (value:gsub("%s+$", ""))
      end
      local module = rip.supported(uname("m"), uname("r"))
      if not module then
        write_status("error:unsupported platform")
      else
        local ok, result, err = pcall(rip.extract, module)
        if ok and result then
          write_status("complete")
        else
          write_status("error:" .. tostring(err or result or "extraction failed"))
        end
      end
    ' || {
      grep -q "^error:" "$STATUS_FILE" 2>/dev/null ||
      echo "error:script failed" > "$STATUS_FILE"
    }
    exit 0
    ;;
  *)
    echo "usage: $0 extract|clear"
    exit 1
    ;;
esac
