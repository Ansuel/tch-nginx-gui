-- copyright © 2015 Technicolor

---
-- A wrapper around /proc/banktable
--
-- @module transformer.shared.banktable
--
-- /proc/banktable exposes the info present in the banktable but
-- judging from some mappings the exact interpretation of the data
-- is somewhat confusing.
--
-- In `/proc/banktable` we can see the following files:
--
--   * `active`
--   * `passive`
--   * `booted`
--   * `notbooted`
--   * `activeversion`
--   * `passiveversion`
--   * `bootedoid`
--   * `notbootedoid`
--
-- `active` contains the name of the bank the bootloader will try
-- to boot first on the next reboot. `passive` is the other bank
--
-- `booted` contains the bank where the current running software
-- booted from. `notbooted` is the other bank.
--
-- `activeversion`, `passiveversion` contain the VRSS infoblock of the
-- bank named in `active` and `passive` respectively or `Unknown`
-- Note that `activeversion` is not always the version of the currently
-- running software as `active` and `booted` can be different either
-- because a switchover was already requested or the software in the
-- `active` bank failed to boot.
--
-- `bootedoid`, `notbootedoid` contains the OID of the software in the
-- bank named in `booted` and `notbooted` respectively.
--
-- The confusion here is introduced by the loose usage of active and
-- passive bank. In the banktable `active`/`passive` is config for the
-- bootloader while `booted`/`notbooted` is the actual runtime info.
--
-- In this module we introduce another, but simpler, definition. We expose
-- two banks:
--
--  * `current`
--  * `other`
--
-- The `current` bank is the bank the current running software booted from.
-- The other bank is, well, the other one. So if the current bank is `"bank_1"`
-- then the other will be `"bank_2"` and vice-versa.
--
-- The functions defined in this module thus return information about either
-- the `current` or the `other` bank and will return the correct info
-- even if `active` is different from `booted`.

--- @alias M
local M = {}

local io = require 'io'
local open = io.open

local function procname(item)
  return "/proc/banktable/"..item
end

local function readproc(item)
  local f = open(procname(item), "r")
  if f then
    local value = f:read("*l")
    f:close()
    return value
  end
end

local function writeproc(item, value)
  local f = open(procname(item), "w")
  if f then
    f:write(value)
    f:close()
    return true
  end
end

--- Determine if the platform is dual bank.
--
-- This determined with the presence of `/proc/banktable/active`.
-- If this entry is not present we assume to  be running on a
-- single bank platform.
-- @return true if dual bank, false if single bank
function M.isDualBank()
  return readproc("active") and true or false
end

--- get the name of the bank the software is running from
-- @return "bank_1" or "bank_2"
-- @return "bank_1" for single bank platforms
function M.getCurrentBank()
  return readproc("booted") or "bank_1"
end

--- get the name of the bank not currently in use
-- @return "bank_1" or "bank_2" for dual bank platforms
-- @return nil for single bank
function M.getOtherBank()
  return readproc("notbooted")
end
local getOtherBank = M.getOtherBank

local function getVersion(current)
  local active = readproc("active")
  local booted = readproc("booted")
  if active~=booted then
    -- in case these do not match, the version to retreive is
    -- actually the opposite one
    current = not current
  end
  return readproc( current and "activeversion" or "passiveversion")
end

--- get the version of the software in the current bank
-- as reported by the infoblock in the bank
function M.getCurrentVersion()
  return getVersion(true)
end

--- get the version of the software in the not current bank
-- as reported by the infoblock in the bank
function M.getOtherVersion()
  return getVersion(false)
end

--- get the OID of the current bank
function M.getCurrentOID()
  return readproc("bootedoid")
end

--- get the OID of the other bank
function M.getOtherOID()
  return readproc("notbootedoid")
end

local function getDeviceName(bank)
  local devname
  local mtd = open("/proc/mtd", "r")
  if mtd then
    for line in mtd:lines() do
      local dev, name = line:match('^([^:]+):.*"([^"]+)"')
      if name==bank then
        devname = "/dev/"..dev
        break
      end
    end
    mtd:close()
  end
  return devname
end

--- has the other bank valid software in it
--
-- A check is made to see if a Linux kernel seems present and
-- the FVP is set to 0.
-- @return true if booting from the other bank seems possible
-- @return false if not
function M.isOtherBankValid()
  local valid = false
  local devname = getDeviceName(getOtherBank())
  if devname then
    local f = open(devname, "rb")
    if f then
      local data = f:read(32)
      f:close()
      if (data:sub(0,4)=="UBI#") then
        local blockSize = 4096
        local pat = "VERSTART"
        local patLength = #pat
        local f = open(devname, "rb")
        local size = f:seek('end')
        f:seek('set', 0)
        local block = f:read(blockSize + patLength)
        while block do
          if block:find(pat) then
            valid = true
            break
          end
          if f:seek('cur')==size then
            break
          end
          f:seek('cur', -patLength)
          block = f:read(blockSize + patLength)
        end
        f:close()
      else
        local fvp = 0
        for i=1,4 do
          fvp = fvp*256 + data:byte(i)
        end
        valid = (fvp==0) and (data:sub(18,21)=="LINU")
      end
    end
   end
  return valid
end

--- instruct the bootloader to boot from the other bank on the next reboot
--
-- This only does banktable manipulation. A reboot will not be triggered.
-- @return true if no error, nil otherwise
function M.prepareSwitchOver()
  local notbooted = readproc("notbooted")
  if notbooted then
    return writeproc("active", notbooted)
  end
end

--- get the bank the bootloader will try to boot on the next reboot
function M.getNextBootBank()
  return readproc("active")
end

return M
