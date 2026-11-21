"""Exercise the RIP inventory and secret extraction without a router."""

from pathlib import Path
import shutil
import subprocess
import unittest


WEB = Path(__file__).resolve().parents[1] / "decompressed/gui_file/www"
RIP_SNIPPET = WEB / "snippets/modgui-rip.lp"
RIP_INDEX = WEB.parent / "usr/share/transformer/scripts/rip_index.lua"
RIP_SCRIPT = WEB.parent / "usr/share/transformer/scripts/ripKeysUtility.sh"
MODGUI_MAP = WEB.parent / "usr/share/transformer/mappings/rpc/system.modgui.map"
LUA = shutil.which("luajit") or shutil.which("lua")

RIP_MOCK = r'''
local snippet = arg[1]
local role, available = "guest", true
local output, opened, calls = {}, {}, {}
local names = {
  "ffff", "0105", "0108", "011B", "0102", "0032", "003c", "0100", "0101", "0116",
  "0104", "0112", "011a", "012b", "0083", "0088", "not-an-id"
}
local values = {
  ["0102"] = "<test>&\0",
  ["011B"] = string.rep("Z", 4097),
  ["0100"] = "public-system-key",
  ["0101"] = "public-rescue-key",
  ["0116"] = "public-rsa-key",
  ["0104"] = "lb-public-certificate",
  ["011a"] = "public-client-certificate",
  ["0112"] = "radio-calibration",
  ["0032"] = "\0\1\2\3\4\5",
  ["0105"] = "private-key-value",
  ["0108"] = "\0\0",
  ["0083"] = "modem\1code\n",
  ["0088"] = "remote-passwd",
  ["012b"] = "randkey-d",
  ["ffff"] = "\1\2",
}
local rpc = {
  ["rpc.system.modgui.utility.rip_index"] = nil,
  ["rpc.system.modgui.utility.rip_status"] = "arch=armv7l;release=3.4.11-rt19;eck=0;module=r2secr.arm.3.4.11-rt19.ko",
  ["rpc.system.modgui.utility.rip_values"] = "",
}

string.untaint = function(value) return value.raw end
package.preload.datamodel = function()
  return { get = function(path)
    calls[#calls + 1] = path
    local value = rpc[path]
    return value and { { value = { raw = value } } } or nil
  end }
end

T = function(s) return s end
ngx = {
  ctx = { session = { getrole = function() return role end } },
  print = function(...) output[#output + 1] = table.concat({...}) end,
}
package.preload.lfs = function()
  return { dir = function(path)
    assert(path == "/proc/rip")
    if not available then error("No such file or directory") end
    local index = 0
    return function()
      index = index + 1
      return names[index]
    end
  end }
end
package.preload["web.web"] = function()
  return { html_escape = function(value)
    return (value:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
  end }
end
io.open = function(path, mode)
  local filename = assert(path:match("^/proc/rip/(%x%x%x%x)$"))
  assert(mode == "rb")
  opened[#opened + 1] = filename
  if filename == "003c" then return nil end
  local value = assert(values[filename], "opened protected or unknown ID: " .. filename)
  return {
    read = function(_, limit)
      assert(limit == 4097)
      return value:sub(1, limit)
    end,
    close = function() end,
  }
end
'''


def run_lua(body, path):
    return subprocess.run([LUA, "-", str(path)], input=body, text=True, capture_output=True)


@unittest.skipUnless(LUA, "Lua interpreter required")
class RipModal(unittest.TestCase):
    def test_inventory_renders_readable_ids_from_proc(self):
        result = run_lua(RIP_MOCK + r'''
dofile(snippet)
assert(#calls == 0 and #opened == 0 and #output == 0)

role = "admin"
dofile(snippet)
local html = table.concat(output)
assert(html:find("&lt;test&gt;&amp;", 1, true))
assert(html:find("0x000102030405", 1, true))
assert(html:find("0x011B", 1, true))
assert(html:find(string.rep("Z", 4096) .. " …", 1, true))
assert(html:find("RIP_ID_FACTORY_ID</td><td>Unknown</td><td style=\"word-break:break-all\">Unavailable", 1, true))
assert(html:find("RIP_ID_PRIVATE_KEY</td><td>Unknown</td><td style=\"word-break:break-all\">private-key-value<", 1, true))
assert(html:find("0xFFFF</td><td>Unknown</td>", 1, true))
assert(html:find("public-system-key", 1, true))
assert(html:find("public-rescue-key", 1, true))
assert(html:find("public-rsa-key", 1, true))
assert(html:find("lb-public-certificate", 1, true))
assert(html:find("public-client-certificate", 1, true))
assert(html:find("radio-calibration", 1, true))
assert(html:find('id="rip-keys-extract"', 1, true))
assert(not html:find('id="rip-keys-clear"', 1, true))
assert(not html:find("No temporary key module", 1, true))
assert(html:find(">0x6D6F64656D01636F6465<", 1, true))
assert(html:find("randkey-d", 1, true))
assert(not html:find("rip-driver", 1, true))
assert(html:find("The modem could not report the encryption status.", 1, true))
assert(not html:find("not-an-id", 1, true))
assert(table.concat(opened, ",") ==
  "0032,003c,0083,0088,0100,0101,0102,0104,0105,0108,0112,0116,011a,011B,012b,ffff")

output, opened = {}, {}
rpc["rpc.system.modgui.utility.rip_index"] =
  "0032=0,0083=0,0088=0,0100=0,0101=1,0102=1,0105=1,0116=0,011a=1,012b=0,4001=1"
dofile(snippet)
html = table.concat(output)
assert(html:find("RIP_ID_LAN_ADDR</td><td>Unencrypted</td>", 1, true))
assert(html:find("RIP_ID_MODELNAME</td><td>Encrypted</td><td style=\"word-break:break-all\">&lt;test&gt;&amp;", 1, true))
assert(html:find("RIP_ID_PRIVATE_KEY</td><td>Encrypted</td><td style=\"word-break:break-all\">private-key-value<", 1, true))
assert(html:find("RIP_ID_ID_DECT_CFG</td><td>Encrypted</td><td style=\"word-break:break-all\">Hidden", 1, true))
assert(html:find("public-rescue-key", 1, true))
assert(html:find("public-client-certificate", 1, true))
assert(table.concat(opened, ",") ==
  "0032,003c,0083,0088,0100,0101,0102,0104,0105,0108,0112,0116,011a,011B,012b,ffff")

-- Extracted keys take precedence and skip reading the proc entries.
output, opened = {}, {}
rpc["rpc.system.modgui.utility.rip_status"] =
  "arch=armv7l;release=4.1.38;eck=1;module=r2secr.arm.4.1.38.ko"
rpc["rpc.system.modgui.utility.rip_values"] = "0105=707269765f6b6579,0108=0000,ffff=010203"
dofile(snippet)
html = table.concat(output)
assert(html:find('id="rip-keys-clear"', 1, true))
assert(not html:find('id="rip-keys-extract"', 1, true))
assert(html:find("RIP_ID_PRIVATE_KEY</td><td>Encrypted</td><td style=\"word-break:break-all\">priv_key<", 1, true))
assert(html:find(">0x0000<", 1, true))
assert(html:find(">0x010203<", 1, true))
assert(html:find("RIP_ID_ID_DECT_CFG</td><td>Encrypted</td><td style=\"word-break:break-all\">Hidden", 1, true))
assert(table.concat(opened, ",") ==
  "0032,003c,0083,0088,0100,0101,0102,0104,0112,0116,011a,011B,012b")

output, opened = {}, {}
rpc["rpc.system.modgui.utility.rip_status"] = "arch=mips;release=2.6.32.1;eck=0;module="
rpc["rpc.system.modgui.utility.rip_values"] = ""
dofile(snippet)
html = table.concat(output)
assert(html:find("No temporary key module is available", 1, true))
assert(html:find("mips</p>", 1, true) or html:find("mips ", 1, true))
assert(not html:find('id="rip-keys-extract"', 1, true))

rpc["rpc.system.modgui.utility.rip_status"] =
  "arch=armv7l;release=4.1.52;eck=0;module=;state=requested 123"
output, opened = {}, {}
dofile(snippet)
html = table.concat(output)
assert(html:find("No temporary key module is available", 1, true))
assert(not html:find('data-poll="1"', 1, true))
assert(html:find("Loading the temporary module", 1, true))

rpc["rpc.system.modgui.utility.rip_status"] =
  "arch=armv7l;release=4.1.52;eck=0;module=r2secr.ko;state=requested 123"
output, opened = {}, {}
dofile(snippet)
html = table.concat(output)
assert(html:find('data-poll="1"', 1, true))
assert(html:find('" disabled>Extract keys', 1, true))

rpc["rpc.system.modgui.utility.rip_status"] =
  "arch=mips;release=3.4.11-rt19;eck=0;module=r2secr.mips.3.4.11-rt19.ko;state=error:request timed out"
output, opened = {}, {}
dofile(snippet)
html = table.concat(output)
assert(html:find('id="rip-keys-extract"', 1, true))
assert(not html:find('data-poll="1"', 1, true))
assert(not html:find('" disabled>Extract keys', 1, true))
assert(html:find("The key extraction failed. request timed out", 1, true))

output, available, opened = {}, false, {}
dofile(snippet)
assert(table.concat(output):find("RIP_ID_LAN_ADDR</td><td>Unencrypted</td><td style=\"word-break:break-all\">Unavailable", 1, true))
assert(#opened == 0)

rpc["rpc.system.modgui.utility.rip_index"] = nil
available = true
role, output, names = "engineer", {}, {}
opened = {}
dofile(snippet)
assert(table.concat(output):find("No RIP parameters are available.", 1, true))
output, available = {}, false
opened = {}
dofile(snippet)
assert(table.concat(output):find("The RIP inventory is unavailable", 1, true))
''', RIP_SNIPPET)
        self.assertEqual(result.returncode, 0, result.stderr)


@unittest.skipUnless(LUA, "Lua interpreter required")
class RipIndex(unittest.TestCase):
    def test_native_index_reads_only_metadata_from_detected_partition(self):
        result = run_lua(r'''
local read = dofile(arg[1]).read
local partition, size = 5, 0x20000
local ro_available = true
local opens, offsets = {}, {}
local entries = {}

local function put(id, first_flag, address, length)
  address = address or 0x20010
  length = length or 8
  entries[#entries + 1] = string.char(
    math.floor(id / 256), id % 256, 0, math.floor(address / 65536),
    math.floor(address / 256) % 256, address % 256, 255, 255, 255, 255,
    first_flag, 255, 255, 255, 0, 0, 0, length
  )
end

io.open = function(path, mode)
  opens[#opens + 1] = path
  if path == "/proc/mtd" then
    assert(mode == "r")
    local lines = {
      'mtd1: 00020000 00010000 "other_eripv2"',
      string.format('mtd%d: %08x 00010000 "eripv2"', partition, size)
    }
    local line = 0
    return {
      lines = function() return function()
        line = line + 1
        return lines[line]
      end end,
      close = function() end,
    }
  end
  local device = "/dev/mtd" .. partition
  assert(mode == "rb")
  if path == device .. "ro" and not ro_available then return nil end
  assert(path == device .. (ro_available and "ro" or ""))
  local index
  return {
    setvbuf = function(_, mode) assert(mode == "no") end,
    seek = function(_, whence, offset)
      assert(whence == "set" and offset >= 0)
      offsets[#offsets + 1] = offset
      index = (size - 4 - offset) / 18
      return offset
    end,
    read = function(_, count)
      assert(count == 18)
      return entries[index]
    end,
    close = function() end,
  }
end

put(0x0102, 0xff)
put(0x0105, 0xe7)
put(0x0105, 0xff)
put(0x0118, 0xef)
put(0xabcd, 0xfd)
entries[#entries + 1] = string.rep(string.char(255), 18)

for _, device in ipairs({4, 5, 12}) do
  partition, opens, offsets = device, {}, {}
  local result = assert(read())
  assert(result["0102"] == false and result["0118"] == false)
  assert(result["0105"] == true and result["abcd"] == true)
  assert(table.concat(opens, ",") == "/proc/mtd,/dev/mtd" .. device .. "ro")
  assert(#offsets == #entries)
  for i, offset in ipairs(offsets) do
    assert(offset == size - 4 - i * 18)
  end
end

ro_available, opens = false, {}
assert(read())
assert(table.concat(opens, ",") == "/proc/mtd,/dev/mtd12ro,/dev/mtd12")

entries[#entries] = nil
assert(read() == nil) -- missing terminator
entries = {}
put(0x0105, 0xe7, 0x20010, 8)
entries[1] = entries[1]:sub(1, 17)
assert(read() == nil) -- short read
entries = {}
put(0x0105, 0xe7, 0x20000 + size - 40 + 1, 0)
entries[2] = string.rep(string.char(255), 18)
assert(read() == nil) -- payload overlaps the terminator
size, opens = 0x200000, {}
assert(read() == nil and #opens == 1)
''', RIP_INDEX)
        self.assertEqual(result.returncode, 0, result.stderr)


@unittest.skipUnless(LUA, "Lua interpreter required")
class RipSecrets(unittest.TestCase):
    """AES-128-CBC against pycryptodome vectors plus extraction plumbing."""

    def test_crypto_parser_and_matrix(self):
        result = run_lua(r'''
local rip = dofile(arg[1])
local function unhex(hex)
  local out = {}
  for byte in hex:gmatch("%x%x") do out[#out + 1] = string.char(tonumber(byte, 16)) end
  return table.concat(out)
end

-- pycryptodome AES-128-CBC vector (IV is the first block).
local key = unhex("718c099c053e95e908769311ba56ccd8")
local payload = unhex("ef6a4ec85be2b948cf94ef149621c632" ..
  "173a1b949c0f8fa97e7cfb8dc1f0a71d18aac0d45bc09e4c52eec69c7bd16f1f" ..
  "d82ce371438279563d0d2a923d1789d5")
local expected = "RIP private key material" .. string.rep("\14", 24)
assert(rip.aes128_cbc(key, payload) == expected)
assert(rip.strip_record(expected, false) == expected:sub(1, 34))
-- FIPS-197 AES-128 ECB vector in CBC with a zero IV.
local cbc = rip.aes128_cbc(unhex("000102030405060708090a0b0c0d0e0f"),
  unhex("0000000000000000000000000000000069c4e0d86a7b0430d8cdb78070b4c55a"))
assert(cbc == unhex("00112233445566778899aabbccddeeff"))
local signed = string.rep("S", 64) .. string.rep("g", 256) .. string.rep(string.char(12), 12)
assert(rip.strip_record(signed, true) == string.rep("S", 64))
assert(rip.strip_record(string.rep("S", 64) .. string.rep("g", 256) .. string.char(200), true) == nil)
assert(rip.aes128_cbc(key, "short") == nil)
local zero_block = string.rep("\0", 16)
local zero_plain = rip.aes128_cbc(key, zero_block .. zero_block)
assert(rip.aes128_cbc(key, zero_block:rep(1024)) == zero_plain:rep(1023))

local log = table.concat({
  "[    2.000000] unrelated 00 11 | ..",
  "[ 2554.482000] r2secr : affdf000 ",
  "[ 2554.700000] nextFreeItem->id : 11f ",
  "[ 2554.701000] nextFreeItem->length : 16 ",
  "[ 2554.702000] nextFreeItem->data : affdf820 ",
  "[ 2554.703000] data_ptr : affdf820 ",
  "[ 2554.704000] 00 11 22 33 44 55 66 77  88 99 AA BB CC DD EE FF  |  ................ ",
  "[ 2554.800000] nextFreeItem->id : 121 ",
  "[ 2554.801000] nextFreeItem->length : 32 ",
  "[ 2554.802000] data_ptr : affdf840 ",
  "[ 2554.803000] 10 20 30 40 50 60 70 80  90 A0 B0 C0 D0 E0 F0 01  |  ........ ........ ",
  "[ 2554.804000] 02 11 22 33 44 55 66 77  88 99 AA BB CC DD EE FF  |  ........ ........ ",
  "[ 2554.900000] module cleanup ",
}, "\n")
local secrets = rip.parse_dmesg(log)
assert(secrets["011f"] == "00112233445566778899aabbccddeeff")
assert(secrets["0121"] == "102030405060708090a0b0c0d0e0f00102112233445566778899aabbccddeeff")
local twice = log .. "\n" .. (log:gsub(
  "00 11 22 33 44 55 66 77  88 99 AA BB CC DD EE FF  |  ................ ",
  "FF EE DD CC BB AA 99 88  77 66 55 44 33 22 11 00  |  ................ "))
assert(rip.parse_dmesg(twice)["011f"] == "ffeeddccbbaa99887766554433221100")
assert(next(rip.parse_dmesg("insmod: can't insert module")) == nil)

assert(rip.supported("armv7l", "3.4.11-rt19").url:find("arm.3.4.11"))
assert(rip.supported("armv7l", "4.1.38 SMP").url:find("arm.4.1.38"))
assert(rip.supported("aarch64", "4.1.45").url:find("arm64"))
assert(rip.supported("mips", "3.4.11-rt19").url:find("mips.3.4"))
assert(rip.supported("mips", "2.6.32.1").url:find("mips.2.6"))
assert(rip.supported("mipsel", "2.6.32") == nil)
assert(rip.supported("mips", "3.10.108") == nil)
assert(rip.supported("armv7l", "4.1.52").local_path)
''', RIP_INDEX)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_extract_flow(self):
        result = run_lua(r'''
local rip = dofile(arg[1])
local runs, files, downloads = {}, {}, 0
local insmod_ok, dmesg, ko_path = true, nil, nil
local ko_sha = nil

local module = rip.supported("mips", "3.4.11-rt19")
ko_path, ko_sha = "/tmp/r2secr-3.4.11-rt19.ko", module.sha256
local download_sha = ko_sha
local download_result = 0

_G.os = setmetatable({}, { __index = os })
os.execute = function(cmd)
  runs[#runs + 1] = cmd
  if cmd:find("^curl ") then
    downloads = downloads + 1
    files[ko_path] = download_sha
    return download_result
  elseif cmd:find("^cp %-f ") then
    local source, destination = cmd:match("^cp %-f (%S+) (%S+)$")
    files[destination] = files[source]
    return files[source] and 0 or 1
  end
  return 0
end
os.remove = function(path) files[path] = nil end
io.popen = function(cmd)
  runs[#runs + 1] = cmd
  local out = ""
  if cmd:find("timeout", 1, true) and cmd:find("true", 1, true) then out = "ok\n"
  elseif cmd:find("sha256sum") then out = files[cmd:match("sha256sum (%S+)")] or ""
  elseif cmd:find("uname %-r") then out = "3.4.11-rt19\n"
  elseif cmd:find("rm %-f") then files[cmd:match("rm %-f (%S+)")] = nil
  elseif cmd:find("insmod") then out = insmod_ok and "" or "insmod: can't insert"
  elseif cmd:find("dmesg") then out = dmesg
  end
  return { read = function() return out end, close = function() end }
end
io.open = function(path, mode)
  if mode == "wb" and path:find("^/tmp/") then
    files[path] = ""
    return { write = function(_, data) files[path] = data end, close = function() end }
  end
  if path == rip.secrets_file then
    if not files[path] then return nil end
    return { read = function() return files[path] end, close = function() end }
  end
  return nil
end

dmesg = table.concat({
  "[ 10.0] r2secr : c0001000 ",
  "[ 10.05] r2secr_struct : c0001000 ",
  "[ 10.05] r2secr_struct->magic : d104ea5b ",
  "[ 10.1] nextFreeItem->id : 11f ",
  "[ 10.2] nextFreeItem->length : 16 ",
  "[ 10.3] data_ptr : c0002000 ",
  "[ 10.4] 00 11 22 33 44 55 66 77  88 99 AA BB CC DD EE FF  |  ................ ",
  "[ 10.5] module cleanup ",
}, "\n")
local secrets = assert(rip.extract(module))
assert(secrets["011f"] == "00112233445566778899aabbccddeeff")
assert(downloads == 1)
assert(files[ko_path] == ko_sha)
assert(files[rip.secrets_file] == "011f=00112233445566778899aabbccddeeff")
local insmods = 0
for _, cmd in ipairs(runs) do if cmd:find("^timeout 15 insmod") then insmods = insmods + 1 end end
assert(insmods == 1)
-- the module is always removed right after the dump
local loaded, removed = 0, 0
for _, cmd in ipairs(runs) do
  if cmd:find("^timeout 15 insmod") then loaded = loaded + 1 end
  if cmd:find("rmmod r2secr") then removed = removed + 1 end
end
assert(loaded == 1 and removed >= 2)

downloads = 0
assert(rip.extract(module)) -- cached module, checksum matches
assert(downloads == 0)

for _, digest in ipairs({"", "bad"}) do
  files[ko_path], download_sha, runs = nil, digest, {}
  local ok, err = rip.extract(module)
  assert(not ok and err == "cannot verify the downloaded module checksum")
  assert(not files[ko_path])
  for _, cmd in ipairs(runs) do assert(not cmd:find("insmod", 1, true)) end
end

files[ko_path], download_sha, download_result = nil, ko_sha, 1
local ok, err = rip.extract(module)
assert(not ok and err == "module download failed" and not files[ko_path])
download_result = 0

insmod_ok = false
ok, err = rip.extract(module)
assert(not ok and err == "insmod: can't insert")
insmod_ok = true

dmesg = "[ 1.0] module cleanup "
ok, err = rip.extract(module)
assert(not ok and err == "the module printed no secrets")

dmesg = table.concat({
  "[ 10.0] r2secr : c0001000 ",
  "[ 10.05] r2secr_struct : c0001000 ",
  "[ 10.05] r2secr_struct->magic : deadbeef ",
  "[ 10.1] nextFreeItem->id : 11f ",
  "[ 10.2] nextFreeItem->length : 16 ",
  "[ 10.3] data_ptr : c0002000 ",
  "[ 10.4] 00 11 22 33 44 55 66 77  88 99 AA BB CC DD EE FF  |  ................ ",
}, "\n")
ok, err = rip.extract(module)
assert(not ok and err == "the module did not find the secrets structure", err)

-- Bundled 4.1.52 module: the struct pointer is patched from the cmdline.
local bundled = rip.supported("armv7l", "4.1.52 SMP preempt mod_unload ARMv7")
assert(bundled and bundled.local_path and bundled.cmdaddr == 660)
assert(bundled.sha256 and #bundled.sha256 == 64)
local cmdline = ".r2secr=0x1ffdf000"
local ko_bytes = string.rep("x", 700)
local patched_bytes = nil
files[bundled.local_path] = bundled.sha256
io.open = function(path, mode)
  if path == "/proc/cmdline" and mode == "rb" then
    return { read = function() return cmdline end, close = function() end }
  end
  if path:find("^/tmp/r2secr") and mode == "rb" then
    return { read = function() return ko_bytes end, close = function() end }
  end
  if path:find("^/tmp/r2secr") and mode == "wb" then
    return { write = function(_, data) patched_bytes = data end, close = function() end }
  end
  if path == rip.secrets_file then return { write = function() end, close = function() end } end
  return nil
end
dmesg = table.concat({
  "[ 10.0]  : 1ffdf000 ",
  "[ 10.05] r2secr_struct : dffdf000 ",
  "[ 10.05] r2secr_struct->magic : d104ea5b ",
  "[ 10.1] nextFreeItem->id : 11f ",
  "[ 10.2] nextFreeItem->length : 16 ",
  "[ 10.3] data_ptr : 1ffdf020 ",
  "[ 10.4] C2 8A 26 85 1D 13 07 CF  33 CF 2F D9 B1 90 EE 4B  |  ..&.....3./....K ",
}, "\n")
local secrets = assert(rip.extract(bundled))
assert(secrets["011f"] == "c28a26851d1307cf33cf2fd9b190ee4b")
assert(patched_bytes and patched_bytes:sub(661, 664) == string.char(0x00, 0xf0, 0xfd, 0x1f))
local cp_cmd
for _, cmd in ipairs(runs) do if cmd:find("cp %-f") then cp_cmd = cmd end end
assert(cp_cmd and cp_cmd:find(bundled.local_path, 1, true))

for _, digest in ipairs({"", "bad"}) do
  files[bundled.local_path], patched_bytes, runs = digest, nil, {}
  local ok, err = rip.extract(bundled)
  assert(not ok and err == "cannot verify the bundled module checksum")
  assert(not patched_bytes)
  for _, cmd in ipairs(runs) do assert(not cmd:find("insmod", 1, true)) end
end

cmdline = "console=ttyS0 root=/dev/mtd2"
local ok2, err2 = rip.extract(bundled)
assert(not ok2 and err2 == "no secrets pointer in the kernel cmdline", err2)
''', RIP_INDEX)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_values_decrypt_eck_records(self):
        result = run_lua(r'''
local rip = dofile(arg[1])
local size = 0x20000
local entries, records = {}, {}
local function put(id, flags, address, payload)
  records[address] = payload
  local xored = address + 0x20000 -- stored addresses are XORed with 0x20000
  table.insert(entries, 1, string.char(
    math.floor(id / 256), id % 256,
    math.floor(xored / 0x1000000) % 256, math.floor(xored / 0x10000) % 256,
    math.floor(xored / 256) % 256, xored % 256,
    255, 255, 255, 255, flags, 255, 255, 255,
    math.floor(#payload / 0x1000000) % 256, math.floor(#payload / 0x10000) % 256,
    math.floor(#payload / 256) % 256, #payload % 256))
end

-- AES vector above reused for the encrypted records.
local iv = "ef6a4ec85be2b948cf94ef149621c632"
local ct = ("173a1b949c0f8fa97e7cfb8dc1f0a71d18aac0d45bc09e4c52eec69c7bd16f1f" ..
  "d82ce371438279563d0d2a923d1789d5")
local function unhex(hex)
  local out = {}
  for byte in hex:gmatch("%x%x") do out[#out + 1] = string.char(tonumber(byte, 16)) end
  return table.concat(out)
end
local key = "718c099c053e95e908769311ba56ccd8"

put(0x0102, 0xff, 0x10, "ModelName")
put(0x0105, 0xf7, 0x100, unhex(iv .. ct)) -- ECK encrypted
put(0x011f, 0xf7, 0x200, unhex(iv .. ct)) -- ECK itself: RAM copy wins
put(0x0083, 0xfd, 0x300, "beksecret") -- BEK encrypted: stays hidden

local index_bytes = table.concat(entries) .. string.rep(string.char(255), 4)
local partition = {}
for _ = 1, size - #index_bytes do partition[#partition + 1] = "\255" end
for address, payload in pairs(records) do
  for i = 1, #payload do partition[address + i] = payload:sub(i, i) end
end
local blob = table.concat(partition) .. index_bytes

io.open = function(path, mode)
  if path == "/proc/mtd" then
    return { lines = function()
      local done = false
      return function()
        if done then return end
        done = true
        return 'mtd5: 00020000 00010000 "eripv2"'
      end
    end, close = function() end }
  end
  if path == "/dev/mtd5ro" then
    local position = 0
    return {
      setvbuf = function() end,
      seek = function(_, whence, offset) position = offset return offset end,
      read = function(_, count)
        local out = blob:sub(position + 1, position + count)
        position = position + count
        return out
      end,
      close = function() end,
    }
  end
  if path == rip.secrets_file then
    return { read = function() return "011f=" .. key .. "\n0121=aabb" end, close = function() end }
  end
  return nil
end

local flags = rip.read()
assert(flags["0102"] == false and flags["0105"] == true and flags["0083"] == true)
local values = rip.values()
assert(values["011f"] == key)
assert(values["0121"] == "aabb")
assert(values["0102"] == nil)
assert(values["0083"] == nil)
assert(unhex(values["0105"]) == ("RIP private key material" .. string.rep("\14", 24)):sub(1, 34))
''', RIP_INDEX)
        self.assertEqual(result.returncode, 0, result.stderr)


    def test_status_and_clear(self):
        result = run_lua(r'''
local rip = dofile(arg[1])
local files = { [rip.status_file] = "requested 123;; \n" }
local now = 422
os.time = function() return now end
os.remove = function(path) files[path] = nil end
io.open = function(path, mode)
  if path == rip.status_file and mode == "rb" and files[path] then
    return { read = function() return files[path] end, close = function() end }
  end
  return nil
end
assert(rip.status() == "requested 123")
now = 423
assert(rip.status() == "error:request timed out")
files[rip.status_file] = nil
assert(rip.status() == "")
files[rip.secrets_file] = "011f=aa"
rip.clear()
assert(files[rip.secrets_file] == nil and files[rip.status_file] == nil)
''', RIP_INDEX)
        self.assertEqual(result.returncode, 0, result.stderr)


@unittest.skipUnless(LUA, "Lua interpreter required")
class RipKeysScript(unittest.TestCase):
    """The embedded Lua of ripKeysUtility.sh drives the async status file."""

    def embedded_lua(self):
        text = RIP_SCRIPT.read_text()
        start = text.index("lua -e '") + len("lua -e '")
        end = text.index("\n    ' ||")
        return text[start:end]

    def run_state(self, supported, extract):
        body = r'''
local statuses = {}
local supported = ''' + supported + r'''
local extract = ''' + extract + r'''
dofile = function(path)
  assert(path == "/usr/share/transformer/scripts/rip_index.lua")
  return { supported = supported, extract = extract }
end
io.open = function(path, mode)
  assert(path == "/tmp/rip_keys_status" and mode == "wb")
  return { write = function(_, data) statuses[#statuses + 1] = data end, close = function() end }
end
io.popen = function(cmd)
  assert(cmd:find("^uname "))
  return { read = function() return (cmd:find("%-r$") and "3.4.11-rt19" or "mips") .. "\n" end,
           close = function() end }
end
''' + self.embedded_lua() + r'''
print(statuses[1] or "")
'''
        result = run_lua(body, RIP_SCRIPT)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout.strip()

    def test_status_state_machine(self):
        self.assertEqual(
          self.run_state("function() return nil end", 'function() error("must not run") end'),
          "error:unsupported platform")
        self.assertEqual(
          self.run_state('function() return { url = "x.ko" } end', "function() return true, {} end"),
          "complete")
        self.assertEqual(
          self.run_state('function() return { url = "x.ko" } end',
                         'function() return nil, "insmod: can\'t insert" end'),
          "error:insmod: can't insert")
        self.assertEqual(
          self.run_state('function() return { url = "x.ko" } end',
                         'function() error("boom;\\nsecond", 0) end'),
          "error:boom second")

    def test_clear_removes_cache_and_status(self):
        script = RIP_SCRIPT.read_text()
        self.assertIn('rm -f /tmp/rip_secrets "$STATUS_FILE"', script)
        self.assertIn("STATUS_FILE=/tmp/rip_keys_status", script)


class RipPlacement(unittest.TestCase):
    def test_only_modgui_includes_rip(self):
        modal = (WEB / "docroot/modals/modgui-modal.lp").read_text()
        backup_key = modal.index('T"Config decrypt key"')
        form_end = modal.index("'</form>'", backup_key)
        include = modal.index('lp.include("modgui-rip.lp")')
        self.assertLess(form_end, include)
        self.assertIn('ngx.header["Cache-Control"] = "no-store"', modal)
        self.assertIn('rip_keys', modal)
        self.assertIn('rip_status', modal)
        self.assertNotIn("rip-modal.lp", (WEB / "snippets/tabs-management.lp").read_text())
        self.assertFalse((WEB / "docroot/modals/rip-modal.lp").exists())
        mapping = MODGUI_MAP.read_text()
        self.assertIn(
          'start-stop-daemon -S -b -x /usr/share/transformer/scripts/ripKeysUtility.sh extract"] = true',
          mapping)
        self.assertIn('Extraction is already running', mapping)


@unittest.skipUnless(LUA, "Lua interpreter required")
class ModguiJsonErrors(unittest.TestCase):
    def test_failed_posts_send_json_without_the_html_error_renderer(self):
        modal = (WEB / "docroot/modals/modgui-modal.lp").read_text()
        helpers = modal[modal.index("local function json_error"):modal.index("local function upgradeguifile")]
        actions = modal[modal.index('        if action == "rip_keys"'):modal.index('        if action == "debug_report"')]
        result = run_lua(r'''
local response, role
local proxy = {
  set = function() return nil, {{errmsg = "Command refused"}} end,
  apply = function() error("must not apply a rejected command") end,
}
local ngx = {
  OK = 0, HTTP_FORBIDDEN = 403, HTTP_CONFLICT = 409,
  ctx = {session = {getrole = function() return role end}},
  header = {},
}
package.preload.dkjson = function()
  return {encode = function(payload)
    assert(payload.success == false and type(payload.error) == "string")
    return payload.error
  end}
end
function ngx.print(body)
  assert(ngx.status == 403 or ngx.status == 409)
  assert(ngx.header.content_type == "application/json")
  assert(response == nil)
  response = body
end
function ngx.exit(status) assert(status == ngx.OK) end
''' + helpers + '\nlocal function rip_post(action, post_args)\n' + actions + '\nend\n' + r'''
sendcmd("checkver")
assert(ngx.status == 409 and response == "Command refused")
response, ngx.status = nil, nil
role = "guest"
rip_post("rip_status", {})
assert(ngx.status == 403 and response == "Insufficient privileges")
response, ngx.status = nil, nil
role = "admin"
rip_post("rip_keys", {command = "extract"})
assert(ngx.status == 409 and response == "Command refused")
''', WEB / "docroot/modals/modgui-modal.lp")
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
