--pretranslated: do not change this file

local session = ngx.ctx.session
local role = session and session:getrole()
if role ~= "admin" and role ~= "engineer" then return end

local lfs = require("lfs")
local escape = require("web.web").html_escape
local datamodel = require("datamodel")

local function rpc_value(path)
  local result = datamodel.get(path)
  local value = result and result[1] and string.untaint(result[1].value)
  return type(value) == "string" and value or ""
end

local packed_index = rpc_value("rpc.system.modgui.utility.rip_index")
local index
if packed_index ~= "" then
  index = {}
  for id, encrypted in packed_index:gmatch("(%x%x%x%x)=([01])") do
    index[id] = encrypted == "1"
  end
end

local platform = {}
for key, value in rpc_value("rpc.system.modgui.utility.rip_status"):gmatch("([%w_]+)=([^;]*)") do
  platform[key] = value
end

-- Values decrypted by Transformer with the keys extracted from kernel RAM
-- (see the rip_index shared library). Empty unless keys were extracted.
local decrypted = {}
for id, hex in rpc_value("rpc.system.modgui.utility.rip_values"):gmatch("(%x%x%x%x)=([0-9a-f]+)") do
  if #hex % 2 == 0 then decrypted[id] = hex end
end

-- ID names from https://github.com/pedro-n-rocha/secr/blob/master/eripv2.py
-- Names from the eRIPv2 catalog; values are shown for every id the driver exposes.
local catalog = {
  ["0000"] = { name = "LOWER_CHECKSUM" },
  ["0002"] = { name = "UNPROT_FREE1" },
  ["0004"] = { name = "PART_NBR_VARIANT" },
  ["0010"] = { name = "ICS" },
  ["0012"] = { name = "BOARD_SERIAL_NBR" },
  ["0022"] = { name = "FACTORY_RELEASE_DATE" },
  ["0028"] = { name = "FIA" },
  ["002c"] = { name = "HANDOVER_DATE" },
  ["0032"] = { name = "LAN_ADDR" },
  ["0038"] = { name = "COMPANY_ID" },
  ["003c"] = { name = "FACTORY_ID" },
  ["0040"] = { name = "BOARD_NAME" },
  ["0048"] = { name = "MEMORY_CONFIG" },
  ["004c"] = { name = "USB_LAN_ADDR" },
  ["0083"] = { name = "MODEM_ACCESS_CODE" },
  ["0088"] = { name = "SECURE_REMOTE_MANG_PASWD" },
  ["008d"] = { name = "WLAN_LAN_ADDR" },
  ["0100"] = { name = "PUBLIC_DSA_SYST" },
  ["0101"] = { name = "PUBLIC_DSA_RESC" },
  ["0102"] = { name = "MODELNAME" },
  ["0103"] = { name = "PRODUCT_CLASS" },
  ["0104"] = { name = "LB_CLIENT_CERTIFICATE" },
  ["0105"] = { name = "PRIVATE_KEY" },
  ["0106"] = { name = "H235_KEY" },
  ["0107"] = { name = "RANDOM_KEY_A" },
  ["0108"] = { name = "RANDOM_KEY_B" },
  ["0109"] = { name = "KEY_PWD" },
  ["0112"] = { name = "RALINK_CALIBRATION_DATA" },
  ["0115"] = { name = "CHIPID" },
  ["0116"] = { name = "PUBLIC_RSA_KEY" },
  ["0118"] = { name = "SERIAL_NBR_BYTES" },
  ["011a"] = { name = "CLIENT_CERTIFICATE" },
  ["011b"] = { name = "OPTICAL_FRONT_END" },
  ["011c"] = { name = "DUID_LLT" },
  ["011e"] = { name = "EIK" },
  ["011f"] = { name = "ECK" },
  ["0120"] = { name = "OSIK" },
  ["0121"] = { name = "OSCK" },
  ["0122"] = { name = "RESTRICTED_DOWNGR_TS" },
  ["0123"] = { name = "RESTRICTED_DOWNGR_OPT" },
  ["0124"] = { name = "GENERIC_ACCESS_KEY_LIST" },
  ["0125"] = { name = "UNLOCK_TAG" },
  ["0127"] = { name = "OLYMPUS_IK" },
  ["0128"] = { name = "OLYMPUS_CK" },
  ["012b"] = { name = "RANDOM_KEY_D" },
  ["4001"] = { name = "ID_DECT_CFG" },
  ["8001"] = { name = "PRODUCT_ID" },
  ["8003"] = { name = "VARIANT_ID" },
}

local rip_dir = "/proc/rip"
local filenames, ids = {}, {}
local dir_ok, entries, directory = pcall(lfs.dir, rip_dir)
if dir_ok and entries then
  for filename in entries, directory do
    if filename:match("^%x%x%x%x$") then
      local id = filename:lower()
      if not filenames[id] then
        filenames[id] = filename
        ids[#ids + 1] = id
      end
    end
  end
end
for id in pairs(index or {}) do
  if not filenames[id] then ids[#ids + 1] = id end
end
table.sort(ids)

local max_value_bytes = 4096
local function format_bytes(data)
  local truncated = #data > max_value_bytes
  data = data:sub(1, max_value_bytes)
  local plain = data:gsub("[%z\r\n]+$", "")
  if plain == "" or plain:find("[^ -~]") then
    data = "0x" .. data:gsub(".", function(byte)
      return string.format("%02X", byte:byte())
    end)
  else
    data = plain
  end
  if truncated then data = data .. " …" end
  return data
end

local function read_value(filename)
  local file = io.open(rip_dir .. "/" .. filename, "rb")
  if not file then return T"Unavailable" end
  local data, err = file:read(max_value_bytes + 1)
  file:close()
  if err then return T"Unavailable" end
  if not data then return T"Empty" end
  data = data:gsub("\n$", "") -- the proc entry terminates string values with a newline
  return format_bytes(data)
end

local function hex_value(hex)
  local data = hex:gsub("%x%x", function(byte)
    return string.char(tonumber(byte, 16))
  end)
  return format_bytes(data)
end

local failed = T"The key extraction failed."
local extracting = T"Loading the temporary module and extracting keys…"
local status_state = platform.state or ""
local status_text = ""
if status_state:match("^requested") then
  status_text = extracting
elseif status_state:match("^error:") then
  status_text = failed .. " " .. status_state:sub(7) -- strip "error:"
end

local requesting = platform.eck ~= "1" and platform.module and platform.module ~= ""
  and status_state:match("^requested")
ngx.print('<fieldset id="rip-keys" data-failed="', escape(failed),
  '" data-requesting="', escape(extracting), '"',
  requesting and ' data-poll="1"' or '', '><legend>',
  T"RIP device keys", '</legend>')
if platform.eck == "1" then
  ngx.print('<p id="rip-keys-status" role="status">', escape(status_text),
    T"Device keys are cached in /tmp: every parameter readable with those keys is decrypted below. The cache is lost on reboot; remove it manually after use.", '</p>',
    '<button type="button" class="btn" id="rip-keys-clear" data-command="clear">',
    T"Remove keys", '</button>')
elseif platform.module and platform.module ~= "" then
  ngx.print('<p>', T"Load the temporary", ' ', escape(platform.module), ' ',
    T"module from github.com/pedro-n-rocha/secr to read the device keys from kernel RAM and decrypt the encrypted parameters below. The module is never written to flash, it is removed immediately after the dump and everything is lost on reboot. Use at your own risk.", '</p>',
    '<p id="rip-keys-status" role="status">', escape(status_text), '</p>')
  ngx.print('<button type="button" class="btn" id="rip-keys-extract" data-command="extract" data-pending="',
    escape(extracting), '"', requesting and ' disabled' or '', '>', T"Extract keys", '</button>')
else
  ngx.print('<p id="rip-keys-status" role="status">', T"No temporary key module is available for this platform", ': ',
    escape(platform.arch or "?"), ' ', escape(platform.release or "?"),
    '. ', T"Encrypted parameters stay hidden.", '</p>')
end
ngx.print('</fieldset>')

ngx.print('<fieldset><legend>', T"RIP Parameters", '</legend>')
if #ids == 0 then
  if dir_ok and entries then
    ngx.print('<p>', T"No RIP parameters are available.", '</p>')
  else
    ngx.print('<p>', T"The RIP inventory is unavailable on this firmware.", '</p>')
  end
else
  if not index then
    ngx.print('<p>', T"The modem could not report the encryption status.", '</p>')
  end
  ngx.print('<table class="table table-striped"><thead><tr><th>', T"ID",
    '</th><th>', T"Parameter", '</th><th>', T"Storage", '</th><th>', T"Value", '</th></tr></thead><tbody>')
  for _, id in ipairs(ids) do
    local entry = catalog[id]
    local name = entry and ("RIP_ID_" .. entry.name) or T"Unknown"
    local encrypted = index and index[id]
    local storage = T"Unknown"
    if encrypted ~= nil then
      storage = encrypted and T"Encrypted" or T"Unencrypted"
    end
    -- ripdrv decrypts encrypted entries in /proc/rip, so every readable
    -- entry is shown; only ids the driver hides (master keys) need the
    -- RAM-extracted values from the temporary r2secr module.
    local value = T"Unavailable"
    if decrypted[id] then
      value = hex_value(decrypted[id])
    elseif filenames[id] then
      value = read_value(filenames[id])
    elseif encrypted then
      value = T"Hidden"
    end
    ngx.print('<tr><td>', "0x" .. id:upper(), '</td><td>', name,
      '</td><td>', storage, '</td><td style="word-break:break-all">', escape(value), '</td></tr>')
  end
  ngx.print('</tbody></table>')
end
ngx.print('</fieldset>')

ngx.print('<script>\
(function() {\
  var section = document.getElementById("rip-keys");\
  if (!section) return;\
  var status = document.getElementById("rip-keys-status");\
  var failed = section.getAttribute("data-failed");\
  var busy = false;\
  var token = function() { return $("meta[name=CSRFtoken]").attr("content"); };\
\
  function showError(button, error) {\
    busy = false;\
    button.prop("disabled", false);\
    status.textContent = failed + (error ? " " + error : "");\
  }\
\
  function poll(button, deadline) {\
    if (Date.now() >= deadline) { showError(button); return; }\
    function retry() { window.setTimeout(function() { poll(button, deadline); }, 2000); }\
    $.ajax({ url: "/modals/modgui-modal.lp", type: "POST", dataType: "json", timeout: 8000,\
      data: { action: "rip_status", CSRFtoken: token() }\
    }).done(function(data) {\
      var state = data && data.status || "";\
      var error = state.match(/(?:^|;)state=error:(.*)$/);\
      if (error) { showError(button, error[1]); return; }\
      if (/(?:^|;)eck=1(?:;|$)/.test(state)) { window.location.reload(); return; }\
      retry();\
    }).fail(retry);\
  }\
\
  function pollExtraction(button) {\
    busy = true;\
    poll(button, Date.now() + 300000);\
  }\
\
  if (section.getAttribute("data-poll")) {\
    status.textContent = section.getAttribute("data-requesting");\
    pollExtraction($("#rip-keys-extract"));\
  }\
\
  $("#rip-keys-extract,#rip-keys-clear").on("click", function() {\
    if (busy) return false;\
    busy = true;\
    var button = $(this);\
    button.prop("disabled", true);\
    if (button.data("pending")) status.textContent = button.data("pending");\
    $.ajax({ url: "/modals/modgui-modal.lp", type: "POST", dataType: "json", timeout: 10000,\
      data: { action: "rip_keys", command: button.data("command"), CSRFtoken: token() }\
    })\
    .done(function() {\
      if (button.data("command") === "extract") pollExtraction(button);\
      else window.location.reload();\
    })\
    .fail(function(request) {\
      showError(button, request.responseJSON && request.responseJSON.error);\
    });\
    return false;\
  });\
})();\
</script>\
');
