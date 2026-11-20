local unpack = unpack or table.unpack

local M = {}

local function partition()
  local file = io.open("/proc/mtd", "r")
  if not file then return end

  local device, size
  for line in file:lines() do
    device, size = line:match('^mtd(%d+):%s+(%x+)%s+%x+%s+"eripv2"%s*$')
    if device then break end
  end
  file:close()
  if device then return "/dev/mtd" .. device, tonumber(size, 16) end
end

local function uint32(data, offset)
  local a, b, c, d = data:byte(offset, offset + 3)
  return ((a * 256 + b) * 256 + c) * 256 + d
end

-- eRIPv2 attribute bits (active-low in the first crypto flag byte).
local ECK_ENCRYPTED, BEK_ENCRYPTED, EIK_SIGNED = 8, 2, 16

local function read_index(file, size)
  local entry_size, trailer_size = 18, 4
  local entries, payload_end = {}, 0
  -- eRIPv2 entries are big-endian and run backwards from the flash trailer.
  for offset = size - trailer_size - entry_size, 0, -entry_size do
    if not file:seek("set", offset) then return end
    local entry = file:read(entry_size)
    if not entry or #entry ~= entry_size then return end

    local high, low = entry:byte(1, 2)
    if high == 255 and low == 255 then
      if next(entries) and payload_end <= offset then return entries end
      return
    end

    -- The stored address is XORed with 0x20000.
    local address = uint32(entry, 3)
    address = address + (address % 0x40000 < 0x20000 and 0x20000 or -0x20000)
    payload_end = math.max(payload_end, address + uint32(entry, 15))
    if payload_end > offset then return end

    local id = string.format("%02x%02x", high, low)
    local flags = entry:byte(11)
    if not entries[id] then
      entries[id] = {
        encrypted = flags % 16 < ECK_ENCRYPTED or flags % 4 < BEK_ENCRYPTED,
        eck = flags % 16 < ECK_ENCRYPTED,
        signed = flags % 32 < EIK_SIGNED,
        address = address,
        length = uint32(entry, 15)
      }
    end
  end
end

local function open_partition()
  local device, size = partition()
  if not size or size < 40 or size > 1024 * 1024 then return end
  local file = io.open(device .. "ro", "rb") or io.open(device, "rb")
  if not file then return end
  file:setvbuf("no")
  return file, size
end

function M.read()
  local file, size = open_partition()
  if not file then return end
  local entries = read_index(file, size)
  file:close()
  if not entries then return end
  local flags = {}
  for id, entry in pairs(entries) do flags[id] = entry.encrypted end
  return flags
end

local max_record_bytes = 16384

local function read_record(file, size, entry)
  if entry.address + entry.length > size then return end
  if not file:seek("set", entry.address) then return end
  return file:read(math.min(entry.length, max_record_bytes))
end

-- Temporary key extraction modules from https://github.com/pedro-n-rocha/secr.
-- They only read kernel RAM and are removed immediately after the dump.
local base_url = "https://raw.githubusercontent.com/pedro-n-rocha/secr/master/"
M.modules = {
  { arch = "armv7l", release = "^3%.4%.11", url = base_url .. "r2secr.arm.3.4.11-rt19.ko",
    sha256 = "3520b7eb9b58b718c8bdae13319d00f6d92702ea712d69e9df7948bd15c4dbbd" },
  { arch = "armv7l", release = "^4%.1%.38", url = base_url .. "r2secr.arm.4.1.38.ko",
    sha256 = "b70698bd24b864f4fbb38db83848a05d7f7648f841c30452951f04d910b51857" },
  -- Broadcom BCM963138 (VBNT/VCNT): upstream has no 4.1.52 build and the
  -- kernel exports the r2secr symbol as NULL, so this is the 4.1.38 module
  -- with a patched vermagic and a patched struct pointer: the bootloader
  -- passes the secrets address in the kernel cmdline (.r2secr=0x...), which
  -- extract() writes at cmdaddr before loading. Pending upstream support:
  -- https://github.com/pedro-n-rocha/secr/pull/13
  { arch = "armv7l", release = "^4%.1%.52",
    local_path = "/usr/share/transformer/scripts/r2secr.arm.4.1.52-cmdline.ko",
    sha256 = "891819ccfaa3b2211ecc5bdc887ba0b6808a4d3ff6553da5b638ce7e70e71333",
    cmdaddr = 660 },
  { arch = "aarch64", release = "^4%.1%.45", url = base_url .. "r2secr.arm64.4.1.45.ko",
    sha256 = "eff63cc4e57f092933a80242a23b618cbcbbc836335630936e4b424081c6f8ea" },
  { arch = "mips", release = "^3%.4%.11", url = base_url .. "r2secr.mips.3.4.11-rt19.ko",
    sha256 = "2150959df3061ad9bbf049c3c444c1cb737ba21205a3edc920b7b9e2a3a3edd8" },
  { arch = "mips", release = "^2%.6", url = base_url .. "r2secr.mips.2.6.ko",
    sha256 = "692cc1fedde821280347282555ffb15cdcb96f5e7cabec633a81186946ba03f0" }
}

function M.supported(arch, release)
  arch, release = tostring(arch or ""), tostring(release or "")
  for _, module in ipairs(M.modules) do
    if arch == module.arch and release:match(module.release) then return module end
  end
end

-- r2secr dumps every in-RAM RIP secret to the kernel log as
-- "nextFreeItem->id : <hex>" followed by a hexdump line.
function M.parse_dmesg(text)
  local secrets = {}
  local id, length, pending = nil, 0, {}
  for line in (text or ""):gmatch("[^\n]+") do
    local body = line:match("^%[%s*%d+%.%d+%]%s*(.-)%s*$") or line
    local item = body:match("^nextFreeItem%->id%s*:%s*(%x+)$")
    local size = body:match("^nextFreeItem%->length%s*:%s*(%d+)$")
    local digits = body:match("^([0-9A-Fa-f ]+)%s*|%s")
    if item then
      id, length, pending = string.format("%04x", tonumber(item, 16)), 0, {}
    elseif size and id then
      length = tonumber(size)
    elseif id and digits and length > 0 then
      for byte in digits:gmatch("%x%x") do pending[#pending + 1] = byte:lower() end
      if #pending >= length then
        if id ~= "0000" then secrets[id] = table.concat(pending, "", 1, length) end
        id = nil
      end
    elseif body ~= "" and not body:match("^nextFreeItem") and not body:match("^data_ptr")
      and not body:match("^r2secr") then
      id = nil
    end
  end
  return secrets
end

M.secrets_file = "/tmp/rip_secrets"
M.status_file = "/tmp/rip_keys_status"

function M.secrets()
  local file = io.open(M.secrets_file, "rb")
  if not file then return end
  local text = file:read("*a") or ""
  file:close()

  local secrets = {}
  for id, hex in text:gmatch("(%x%x%x%x)=([0-9a-f]+)") do
    if #hex % 2 == 0 then secrets[id] = hex end
  end
  return next(secrets) and secrets
end

function M.clear_secrets()
  os.remove(M.secrets_file)
end

function M.clear()
  M.clear_secrets()
  os.remove(M.status_file)
end

function M.status()
  local file = io.open(M.status_file, "rb")
  if not file then return "" end
  local text = file:read("*a") or ""
  file:close()
  return (text:gsub("[;%s]+$", ""))
end

local function shell(command)
  -- the braces group compound commands so 2>/dev/null covers them all
  local handle = io.popen("{ " .. command .. " ; } 2>/dev/null", "r")
  if not handle then return "" end
  local output = handle:read("*a") or ""
  handle:close()
  return (output:gsub("%s+$", ""))
end

function M.cmdline_secrets_address()
  local file = io.open("/proc/cmdline", "rb")
  if not file then return end
  local cmdline = file:read("*a") or ""
  file:close()
  local address = cmdline:match("[.%s]r2secr=0x(%x+)")
  return address and tonumber(address, 16)
end

-- The web worker runs as nobody, so this runs inside Transformer (root).
-- Everything is temporary: the module is loaded from /tmp and removed right
-- after the dump, and the extracted keys only live in /tmp until reboot.
function M.extract(module)
  local kernel = (shell("uname -r"):gsub("%s+$", "")):gsub("[^%w%+%.%-]", "-")
  local ko = "/tmp/r2secr-" .. kernel .. ".ko"
  if module.local_path then
    local address = M.cmdline_secrets_address()
    if not address then return nil, "no secrets pointer in the kernel cmdline" end
    shell("cp -f " .. module.local_path .. " " .. ko)
    local patched = io.open(ko, "rb")
    if not patched then return nil, "module is missing from the GUI" end
    local bytes = patched:read("*a")
    patched:close()
    if #bytes < module.cmdaddr + 4 then return nil, "module is truncated" end
    bytes = bytes:sub(1, module.cmdaddr) ..
      string.char(address % 256, math.floor(address / 256) % 256,
        math.floor(address / 65536) % 256, math.floor(address / 16777216) % 256) ..
      bytes:sub(module.cmdaddr + 5)
    patched = io.open(ko, "wb")
    if not patched then return nil, "cannot write the module cache" end
    patched:write(bytes)
    patched:close()
  elseif shell("sha256sum " .. ko):match("^(%x+)") ~= module.sha256 then
    shell("rm -f " .. ko)
    os.execute("curl -fksL --max-time 60 -o " .. ko .. " '" .. module.url .. "'")
    if shell("test -s " .. ko .. " && echo ok") ~= "ok" then
      return nil, "module download failed"
    end
    local sum = shell("sha256sum " .. ko):match("^(%x+)")
    if sum and sum ~= module.sha256 then
      shell("rm -f " .. ko)
      return nil, "module checksum mismatch"
    end
  end

  shell("rmmod r2secr")
  -- Guard against modules whose init never returns (bad struct layout loops
  -- printing hexdump lines forever). BusyBox builds differ on where the
  -- timeout number goes, so probe both spellings first.
  local timeout = ""
  if shell("timeout 1 true && echo ok"):match("^ok") then
    timeout = "timeout 15 "
  elseif shell("timeout -t 1 true && echo ok"):match("^ok") then
    timeout = "timeout -t 15 "
  end
  local insmod = io.popen(timeout .. "insmod " .. ko .. " 2>&1", "r")
  local insmod_error = insmod and insmod:read("*a") or ""
  if insmod then insmod:close() end
  local log = shell("dmesg")
  shell("rmmod r2secr")
  if insmod_error:match("%S") then
    return nil, insmod_error:gsub("%s+$", "")
  end

  -- Keep only the newest dump when old runs are still in the kernel log.
  -- The struct line is the anchor: the cmdline-pointer patch overwrites the
  -- first format string of the bundled module, "r2secr :" is not reliable.
  local dump, from = nil, 1
  while true do
    local pos = log:find("r2secr_struct : ", from, true)
    if not pos then break end
    dump = log:sub(pos)
    from = pos + 16
  end
  -- A wrong struct pointer walks uninitialised memory forever; trust the
  -- dump only when the secrets magic is the expected one.
  if dump and not dump:find("r2secr_struct%->magic%s*:%s*d104ea5b") then
    return nil, "the module did not find the secrets structure"
  end
  local secrets = M.parse_dmesg(dump or "")

  local keys = {}
  for id, hex in pairs(secrets) do keys[#keys + 1] = id .. "=" .. hex end
  table.sort(keys)
  if #keys == 0 then return nil, "the module printed no secrets" end

  local file = io.open(M.secrets_file, "wb")
  if not file then return nil, "cannot write the key cache" end
  file:write(table.concat(keys, "\n"))
  file:close()
  return secrets
end

local xornib = {}
do
  local function nibble_xor(a, b)
    local result, bit = 0, 1
    for _ = 1, 4 do
      if a % 2 ~= b % 2 then result = result + bit end
      a, b, bit = math.floor(a / 2), math.floor(b / 2), bit * 2
    end
    return result
  end
  for a = 0, 15 do
    xornib[a] = {}
    for b = 0, 15 do xornib[a][b] = nibble_xor(a, b) end
  end
end

local function bxor(a, b)
  a, b = math.floor(a), math.floor(b)
  return xornib[a % 16][b % 16] + 16 * xornib[math.floor(a / 16)][math.floor(b / 16)]
end

local aes_exp, aes_log, sbox, inv_sbox = {}, {}, {}, {}
do
  local function xtime(value)
    local high = value >= 128
    value = (value * 2) % 256
    if high then value = bxor(value, 0x1b) end
    return value
  end

  -- 2 has order 51 modulo x^8+x^4+x^3+x+1, so the log table uses 3.
  local value = 1
  for i = 0, 254 do
    aes_exp[i], aes_log[value] = value, i
    value = bxor(value, xtime(value))
  end
  aes_exp[255] = 1
  for i = 0, 255 do
    local inverse = i == 0 and 0 or aes_exp[255 - aes_log[i]]
    local coded = inverse
    for _, shift in ipairs({ 1, 2, 3, 4 }) do
      coded = bxor(coded, (inverse * (2 ^ shift)) % 256 + math.floor(inverse / (2 ^ (8 - shift))))
    end
    sbox[i] = bxor(coded, 0x63)
  end
  for i = 0, 255 do inv_sbox[sbox[i]] = i end
end

local function aes_mul(a, b)
  if a == 0 or b == 0 then return 0 end
  return aes_exp[(aes_log[a] + aes_log[b]) % 255]
end

local mul9, mul11, mul13, mul14 = {}, {}, {}, {}
for i = 0, 255 do
  mul9[i], mul11[i], mul13[i], mul14[i] = aes_mul(i, 9), aes_mul(i, 11), aes_mul(i, 13), aes_mul(i, 14)
end

local function expand_key(key)
  local words = {}
  for i = 0, 3 do
    local word = {}
    for byte = 1, 4 do word[byte] = key:byte(i * 4 + byte) end
    words[i] = word
  end
  local rcon = 1
  for i = 4, 43 do
    local temp = { words[i - 1][1], words[i - 1][2], words[i - 1][3], words[i - 1][4] }
    if i % 4 == 0 then
      temp[1], temp[2], temp[3], temp[4] = sbox[temp[2]], sbox[temp[3]], sbox[temp[4]], sbox[temp[1]]
      temp[1] = bxor(temp[1], rcon)
      if rcon >= 128 then rcon = bxor((rcon * 2) % 256, 0x1b) else rcon = rcon * 2 end
    end
    local word = {}
    for byte = 1, 4 do word[byte] = bxor(words[i - 4][byte], temp[byte]) end
    words[i] = word
  end
  return words
end

local function inv_shift_rows(state)
  local shifted = {}
  for row = 0, 3 do
    for column = 0, 3 do
      shifted[column * 4 + row + 1] = state[((column - row) % 4) * 4 + row + 1]
    end
  end
  return shifted
end

local function add_round_key(state, words, round)
  for column = 0, 3 do
    for row = 0, 3 do
      local index = column * 4 + row + 1
      state[index] = bxor(state[index], words[round * 4 + column][row + 1])
    end
  end
  return state
end

local function decrypt_block(state, words)
  state = add_round_key(state, words, 10)
  for round = 9, 1, -1 do
    state = inv_shift_rows(state)
    for i = 1, 16 do state[i] = inv_sbox[state[i]] end
    state = add_round_key(state, words, round)
    for column = 0, 3 do
      local base = column * 4
      local a1, a2, a3, a4 = state[base + 1], state[base + 2], state[base + 3], state[base + 4]
      state[base + 1] = bxor(bxor(mul14[a1], mul11[a2]), bxor(mul13[a3], mul9[a4]))
      state[base + 2] = bxor(bxor(mul9[a1], mul14[a2]), bxor(mul11[a3], mul13[a4]))
      state[base + 3] = bxor(bxor(mul13[a1], mul9[a2]), bxor(mul14[a3], mul11[a4]))
      state[base + 4] = bxor(bxor(mul11[a1], mul13[a2]), bxor(mul9[a3], mul14[a4]))
    end
  end
  state = inv_shift_rows(state)
  for i = 1, 16 do state[i] = inv_sbox[state[i]] end
  return add_round_key(state, words, 0)
end

-- eRIPv2 payloads are AES-128-CBC with the IV stored in the first block.
function M.aes128_cbc(key, data)
  if #key ~= 16 or #data < 32 or #data % 16 ~= 0 then return nil end

  local words = expand_key(key)
  local previous = { data:byte(1, 16) }
  local plain = {}
  for offset = 17, #data, 16 do
    local block = { data:byte(offset, offset + 15) }
    local cipher = { data:byte(offset, offset + 15) }
    local decrypted = decrypt_block(block, words)
    for i = 1, 16 do plain[#plain + 1] = bxor(decrypted[i], previous[i]) end
    previous = cipher
  end
  return string.char(unpack(plain))
end

-- Signed records keep a 256-byte signature before the trailing pad bytes.
function M.strip_record(plain, signed)
  local pad = plain:byte(#plain)
  if signed then
    local size = #plain - pad - 256
    if size < 0 then return end
    return plain:sub(1, size)
  end
  if pad >= 1 and pad <= 16 and pad <= #plain then return plain:sub(1, #plain - pad) end
  return plain
end

local function hex_to_bytes(hex)
  local bytes = {}
  for byte in hex:gmatch("%x%x") do bytes[#bytes + 1] = string.char(tonumber(byte, 16)) end
  return table.concat(bytes)
end

-- Plaintext values for every record that the extracted ECK can open.
-- In-RAM secrets are authoritative; ECK-encrypted flash records are
-- decrypted here. BEK records stay hidden (the key is device-unique
-- and not exposed by r2secr, same limitation as secr's eripv2.py).
function M.values()
  local secrets = M.secrets()
  if not secrets then return end

  local values = {}
  for id, hex in pairs(secrets) do values[id] = hex end

  local key = secrets["011f"] and hex_to_bytes(secrets["011f"])
  if not key then return values end

  local file, size = open_partition()
  if not file then return values end
  local entries = read_index(file, size)
  if entries then
    for id, entry in pairs(entries) do
      if entry.eck and not values[id] and entry.length >= 32 and entry.length <= max_record_bytes then
        local data = read_record(file, size, entry)
        local plain = data and M.aes128_cbc(key, data)
        plain = plain and M.strip_record(plain, entry.signed)
        if plain then
          local hex = {}
          for byte = 1, #plain do
            hex[byte] = string.format("%02x", plain:byte(byte))
          end
          values[id] = table.concat(hex)
        end
      end
    end
  end
  file:close()
  return values
end

return M
