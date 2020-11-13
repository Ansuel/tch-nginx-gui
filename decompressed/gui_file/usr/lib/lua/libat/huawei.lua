local firmware_upgrade = require("libat.firmware_upgrade")
local helper = require("mobiled.scripthelpers")
local session_helper = require("libat.session")
local voice = require("libat.voice")
local attty = require("libat.tty")
local sim = require("libat.sim")

local tinsert = table.insert

-- Apparently there is no reliable way of retrieving this from the module/dongle
local hardcoded_device_capabilities = {
    voice_support = {
        ["K5160"] = { cs_voice_support = true },
        ["K4203"] = { cs_voice_support = true }
    },
    max_data_sessions = {
        ["K4305"] = 2
    }
}

local Mapper = {}
Mapper.__index = Mapper

local M = {}

local function parse_nwtime(data)
    local localtime, timezone, daylight_saving_time = data:match("%^NWTIME:%s?(%d+/%d+/%d+,%d+:%d+:%d+)([+-]%d+),(%d+)")
    if localtime then
        local year, month, day, hour, min, sec = localtime:match("(%d+)/(%d+)/(%d+),(%d+):(%d+):(%d+)")
        if year then
            year = tonumber(year)+2000
            localtime = os.time({day=day,month=month,year=tostring(year),hour=hour,min=min,sec=sec})
        end
    end
    daylight_saving_time = tonumber(daylight_saving_time)
    timezone = tonumber(timezone)
    if timezone then
        timezone = timezone * 15
    end
    return localtime, timezone, daylight_saving_time
end

function Mapper:set_attach_params(device, profile)
    local pdptype, errMsg = session_helper.get_pdp_type(device, profile.pdptype)
    if not pdptype then
        return nil, errMsg
    end
    local apn = profile.apn or ""
    -- ME906s uses profile 0 to auto attach and 1 for the actual data session
    -- They need to be inline or multiple attaches are executed
    -- On other dongles this should have no effect
    device:send_command(string.format('AT+CGDCONT=0,"%s","%s"', pdptype, apn))
    device:send_command(string.format('AT+CGDCONT=1,"%s","%s"', pdptype, apn))

    if profile.authentication and profile.password and profile.username then
        local auth_type = "2" -- default  CHAP
        if profile.authentication == "pap" then
            auth_type = "1"
        end
        device:send_command(string.format('AT^AUTHDATA=0,%d,"","%s","%s"', auth_type, profile.password, profile.username))
        device:send_command(string.format('AT^AUTHDATA=1,%d,"","%s","%s"', auth_type, profile.password, profile.username))
    else
        -- Clear any previously stored authentication data on the auto-attach context
        device:send_command("AT^AUTHDATA=0")
        device:send_command("AT^AUTHDATA=1")
    end
    return true
end

function Mapper:start_data_session(device, session_id, profile)
    local id = session_id + 1
    local session = device.sessions[id]
    if session and session.proto == "ppp" then
        return true
    end

    -- Enable session counters and duration
    device:send_command("AT^DSFLOWRPT=1", 2000)

    local ret = true
    local apn = profile.apn or ""
    if session then
        if not session.context_created then
            local pdptype, errMsg = session_helper.get_pdp_type(device, profile.pdptype)
            if not pdptype then
                return nil, errMsg
            end
            ret = device:send_command(string.format('AT+CGDCONT=%d,"%s","%s"', id, pdptype, apn))
        end

        if ret then
            session.context_created = true
            if profile.authentication and profile.password and profile.username then
                local auth_type = "2" -- Default CHAP
                if profile.authentication == "pap" then
                    auth_type = "1"
                end
                local cmd = string.format('AT^NDISDUP=%d,1,"%s","%s","%s",%d', id, apn, profile.username, profile.password, auth_type)
                return device:send_command(cmd, 5000)
            else
                return device:send_command('AT^NDISDUP=' .. id .. ',1,"' .. apn .. '"', 5000)
            end
        end
    end
end

function Mapper:stop_data_session(device, session_id)
    local id = session_id + 1
    local session = device.sessions[id]
    if session and session.proto == "ppp" then
        return true
    end

    local ret = device:send_command(string.format('AT^NDISDUP=%d,0', id), 5000)
    if session then
        session.context_created = nil
    end
    return ret
end

local function parse_dsflowrpt(device, data)
    local connection_duration, ul_speed, dl_speed, bytes_sent, bytes_received, max_ul_speed, max_dl_speed = data:match('%^DSFLOWRPT:%s?(%x+),(%x+),(%x+),(%x+),(%x+),(%x+),(%x+)')

    if device.buffer.session_info and device.buffer.session_info.duration and tonumber(connection_duration, 16) == 0 then
        device.runtime.log:notice("Wrong info in ^DSFLOWRPT indication. Turning it off.")
        device:send_command('AT^DSFLOWRPT=0')
        device.buffer.session_info = {}
        device.buffer.network_info = {}
        return
    end

    device.buffer.session_info = {
        packet_counters = {
            tx_bytes = tonumber(bytes_sent, 16),
            rx_bytes = tonumber(bytes_received, 16)
        },
        duration = tonumber(connection_duration, 16)
    }
    if not device.buffer.network_info then
        device.buffer.network_info = {}
    end
    device.buffer.network_info.connection_rate = {
        current_ul_speed = tonumber(ul_speed, 16),
        current_dl_speed = tonumber(dl_speed, 16),
        max_ul_speed = tonumber(max_ul_speed, 16),
        max_dl_speed = tonumber(max_dl_speed, 16)
    }
end

local function parse_ndisstat(device, data)
    local state, reject_cause, ip_type = data:match('%^NDISSTAT:%s*(%d+),(.-),.-,"(.-)"')
    if state == '0' then
        local pdp_type
        if ip_type then
            pdp_type = ip_type:lower()
        end
        -- Unknown reject cause
        if reject_cause == '0' then
            reject_cause = nil
        end
        device.buffer.session_info = {}
        device:send_event("mobiled", { event = "session_disconnected", session_id = 0, dev_idx = device.dev_idx, reject_cause = tonumber(reject_cause), pdp_type = pdp_type })
    elseif state == '1' then
        device:send_event("mobiled", { event = "session_connected", session_id = 0, dev_idx = device.dev_idx })
    end
end

local function parse_nwname(device, data)
    local longname, shortname = data:match('%^NWNAME:%s*"(.-)","(.-)"')
    if not device.buffer.network_info then
        device.buffer.network_info = {}
    end
    if not device.buffer.network_info.plmn_info then
        device.buffer.network_info.plmn_info = {}
    end
    if longname and longname ~= "" then
        device.buffer.network_info.plmn_info.description = longname
    elseif shortname and shortname ~= "" then
        device.buffer.network_info.plmn_info.description = shortname
    end
end

local device_errors = {
    [1]   = firmware_upgrade.error_codes.unknown_error, -- Operation failed due to unknown error
    [2]   = firmware_upgrade.error_codes.invalid_state, -- Previous command is not complete
    [3]   = firmware_upgrade.error_codes.invalid_parameters, -- Error command parameters
    [4]   = firmware_upgrade.error_codes.not_supported, -- Operation not supported
    [5]   = firmware_upgrade.error_codes.unknown_error, -- Operation failed due to system error
    [11]  = firmware_upgrade.error_codes.download_failed, -- The network has not been opened yet
    [12]  = firmware_upgrade.error_codes.download_failed, -- The network has been opened already
    [13]  = firmware_upgrade.error_codes.download_failed, -- Fail to open network
    [14]  = firmware_upgrade.error_codes.download_failed, -- The link has not been established yet
    [15]  = firmware_upgrade.error_codes.download_failed, -- The link has been established already
    [16]  = firmware_upgrade.error_codes.download_failed, -- Fail to establish link
    [17]  = firmware_upgrade.error_codes.download_failed, -- Fail to bind the specified port
    [18]  = firmware_upgrade.error_codes.download_failed, -- Fail to connect to the specified address
    [19]  = firmware_upgrade.error_codes.download_failed, -- Invalid domain name
    [20]  = firmware_upgrade.error_codes.download_failed, -- Fail to resolve DNS
    [21]  = firmware_upgrade.error_codes.download_failed, -- Http server error
    [22]  = firmware_upgrade.error_codes.invalid_image, -- File type is not correct
    [23]  = firmware_upgrade.error_codes.download_failed, -- File source is not correct
    [51]  = firmware_upgrade.error_codes.download_failed, -- Fail to get file list
    [52]  = firmware_upgrade.error_codes.invalid_image, -- MD5 check failed
    [54]  = firmware_upgrade.error_codes.download_failed, -- FOTA is in collision state
    [101] = firmware_upgrade.error_codes.download_failed, -- Fail to send data because TE cancel
    [102] = firmware_upgrade.error_codes.download_failed, -- Fail to send data because retry times are bigger than 10
    [103] = firmware_upgrade.error_codes.download_failed, -- Fail to send data because input file size is error
    [104] = firmware_upgrade.error_codes.download_failed, -- Fail to send data because packet number is error
    [105] = firmware_upgrade.error_codes.download_failed, -- Fail to send data because the protocol is not 1K-Xmodem
    [106] = firmware_upgrade.error_codes.download_failed, -- Fail to send data because invalid port
    [107] = firmware_upgrade.error_codes.download_failed, -- Fail to send data because file CRC or subfile CRC is error
    [108] = firmware_upgrade.error_codes.download_failed, -- Fail to send data because update type is error
    [109] = firmware_upgrade.error_codes.download_failed, -- Fail to send data because model product is error
    [110] = firmware_upgrade.error_codes.download_failed, -- Fail to send data because source version is error
    [111] = firmware_upgrade.error_codes.download_failed, -- Fail to send data because some tag length is error
    [112] = firmware_upgrade.error_codes.download_failed, -- Fail to send data because file num error
    [113] = firmware_upgrade.error_codes.download_failed, -- Fail to send data because open subfile failed
    [114] = firmware_upgrade.error_codes.flashing_failed, -- Fail to send data because write subfile to flash error
    [151] = firmware_upgrade.error_codes.flashing_failed, -- Fail to write flag
    [152] = firmware_upgrade.error_codes.flashing_failed, -- Fail to read flag
    [153] = firmware_upgrade.error_codes.flashing_failed, -- Fail to erase region
    [154] = firmware_upgrade.error_codes.flashing_failed, -- Fail to copy osbl
    [155] = firmware_upgrade.error_codes.flashing_failed, -- Fail to replace image
    [156] = firmware_upgrade.error_codes.flashing_failed, -- Fail to copy xnv
    [157] = firmware_upgrade.error_codes.flashing_failed, -- Fail to write xnv
    [158] = firmware_upgrade.error_codes.flashing_failed, -- Fail to backup nv
    [159] = firmware_upgrade.error_codes.flashing_failed -- Fail to restore nv
}

local function parse_fotastate(device, data, unsolicited)
    local state = tonumber(data:match('%^FOTASTATE:%s*(%d+)'))
    local status
    if state == 10 then
        status = "not_running"
    elseif state == 11 then
        device.buffer.firmware_upgrade_info.target_version = nil
        status = "checking_version"
    elseif state == 12 then
        status = "upgrade_available"
        local version = data:match('%^FOTASTATE:%s*%d+,(.-),')
        if version then
            device.buffer.firmware_upgrade_info.target_version = version
        end
    elseif state == 14 then
        device.buffer.firmware_upgrade_info.target_version = nil
        status = "no_upgrade_available"
    elseif state == 30 then
        status = "downloading"
    elseif state == 40 then
        status = "downloaded"
    elseif state == 50 then
        status = "flashing"
    elseif state == 90 then
        status = "done"
    elseif state == 13 or state == 20 or state == 80 then
        status = "failed"
        local device_error = tonumber(data:match('%^FOTASTATE:%s*%d+,(%d+)'))
        device.buffer.firmware_upgrade_info.error_code = device_errors[device_error] or firmware_upgrade.error_codes.unknown_error
        device.buffer.firmware_upgrade_info.device_error = device_error
    end

    if device.buffer.firmware_upgrade_info.status ~= "done" and device.buffer.firmware_upgrade_info.status ~= "failed" then
        device.buffer.firmware_upgrade_info.status = status
    end

    if unsolicited then
        -- Because the device will go away in flashing mode, we store the state and target version in /var/state
        firmware_upgrade.update_state(device, device.buffer.firmware_upgrade_info)
        if status == "done" or status == "no_upgrade_available" then
            device:send_event("mobiled", { event = "firmware_upgrade_done", dev_idx = device.dev_idx })
        elseif status == "failed" then
            device:send_event("mobiled", { event = "firmware_upgrade_failed", dev_idx = device.dev_idx })
        end
    end
end

local function parse_ltersrp(device, data)
    local rsrp, rsrq = data:match('%^LTERSRP:%s*([%d-]+),([%d-]+)')
    device.buffer.radio_signal_info.rsrp = tonumber(rsrp)
    device.buffer.radio_signal_info.rsrq = tonumber(rsrq)
end

local function radio_type_supported(radios, radio_type)
    if type(radios) == "table" then
        for _, radio in pairs(radios) do
            if radio.radio_interface == radio_type then
                return true
            end
        end
    end
    return nil
end

function Mapper:get_sim_info(device, info) --luacheck: no unused args
    if not device.buffer.sim_info.iccid then
        local ret = device:send_singleline_command('AT^ICCID?', "^ICCID:", 100)
        if ret then
            local iccid = ret:match('%^ICCID:%s?(.+)')
            if sim.check_iccid(iccid) then
                device.buffer.sim_info.iccid = iccid
            end
        end
    end
end

function Mapper:get_radio_signal_info(device, info)
    helper.merge_tables(info, device.buffer.radio_signal_info)

    local ret, err = device:send_singleline_command('AT^HCSQ?', "^HCSQ:", 100)
    if ret then
        local type = ret:match('%^HCSQ:%s?"([A-Z]+)"')

        local rssi = tonumber(ret:match('%^HCSQ:%s?"[A-Z]+",(%d+)'))
        if(rssi and rssi > 0 and rssi <= 96) then
            info.rssi = (rssi-120)
        end

        if type == "LTE" then
            info.radio_interface = "lte"
            local rsrp, snr, rsrq = ret:match('%^HCSQ:%s?"[A-Z]+",%d+,(%d+),(%d+),(%d+)')
            rsrp = tonumber(rsrp)
            if(rsrp and rsrp > 0 and rsrp <= 97) then
                info.rsrp = (rsrp-140)
            end
            snr = tonumber(snr)
            if(snr and snr > 0 and snr <= 251) then
                info.snr = ((snr*0.2)-20)
            end
            rsrq = tonumber(rsrq)
            if(rsrq and rsrq > 0 and rsrq <= 34) then
                info.rsrq = ((rsrq*0.5)-19.5)
            end
        elseif type == "WCDMA" then
            info.radio_interface = "umts"
            local rscp, ecio = ret:match('%^HCSQ:%s?"[A-Z]+",%d+,(%d+),(%d+)')
            rscp = tonumber(rscp)
            if(rscp and rscp > 0) then
                info.rscp = ((rscp*0.5)-120)
            end
            ecio = tonumber(ecio)
            if(ecio and ecio > 0) then
                info.ecio = ((ecio*0.5)-32)
            end
        end
    elseif err ~= "blacklisted" then
        tinsert(device.command_blacklist, 'AT%^HCSQ%?')
    end

    ret = device:send_singleline_command('AT^SYSINFOEX', "^SYSINFOEX:")
    if ret then
        info.radio_bearer_type = ret:match('%^SYSINFOEX:%s?%d*,%d*,%d*,%d*,%d*,%d*,".-",%d+,"(.-)"')
        if info.radio_bearer_type == "NO SERVICE" or info.radio_bearer_type == "LTE" then
            info.radio_bearer_type = nil
        end
    end
end

function Mapper:get_pin_info(device, info)
    local ret = device:send_singleline_command('AT^CPIN?', "^CPIN:")
    if ret then
        info.unblock_retries_left, info.unlock_retries_left = ret:match('%^CPIN:.-,%d*,(%d+),(%d+),%d+,%d+')
    end
end

function Mapper:get_ip_info(device, info, session_id)
    local ret = device:send_singleline_command(string.format('AT^DHCPV6=%d', (session_id + 1)), "^DHCPV6:")
    if ret then
        local dns1, dns2 = ret:match("%^DHCPV6:%s*.-,.-,.-,.-,(.-),(.-),")
        if dns1 ~= "::" then info.ipv6_dns1 = dns1 end
        if dns2 ~= "::" then info.ipv6_dns2 = dns2 end
    end
end

local function match_ndisstat(data)
    if not data then
        return
    end
    local stat4, stat6 = data:match('%^NDISSTATQRY:%s?(%d),,,"IPV4",(%d),,,"IPV6"')
    if not stat4 then
        stat4 = data:match('%^NDISSTATQRY:%s?(%d),,,"IPV4"')
        if not stat4 then
            stat4 = data:match('%^NDISSTATQRY:%s?%d,(%d),,,"IPV4"')
        end
    end
    if not stat6 then
        stat6 = data:match('%^NDISSTATQRY:%s?(%d),,,"IPV6"')
        if not stat6 then
            stat6 = data:match('%^NDISSTATQRY:%s?%d,(%d),,,"IPV6"')
        end
    end
    return stat4, stat6
end

function Mapper:get_session_info(device, info, session_id)
    local id = session_id + 1
    if device.sessions[id] and device.sessions[id].proto == "ppp" then
        return true
    end

    info.packet_counters = device.buffer.session_info.packet_counters
    info.duration = device.buffer.session_info.duration

    local ret = device:send_singleline_command(string.format('AT^NDISSTATQRY=%d', id), "^NDISSTATQRY:", 2000)
    local stat4, stat6 = match_ndisstat(ret)
    if stat4 == "1" or stat6 == "1" then
        info.session_state = "connected"
    else
        -- Some modules report 0 instead of ERROR on the above form of the command so check again
        ret = device:send_multiline_command('AT^NDISSTATQRY?', "^NDISSTATQRY:", 2000)
        if ret then
            for _, s in pairs(ret) do
                stat4, stat6 = match_ndisstat(s)
                if stat4 == "1" or stat6 == "1" then
                    info.session_state = "connected"
                end
            end
        end
    end
    if stat4 == "1" then
        info.ipv4 = true
    end
    if stat6 == "1" then
        info.ipv6 = true
    end
end

function Mapper:get_device_capabilities(device, info)
    local radio_interfaces = {}

    if device.buffer.device_info.model then
        info.max_data_sessions = hardcoded_device_capabilities.max_data_sessions[device.buffer.device_info.model] or 1
        local voice_support = hardcoded_device_capabilities.voice_support[device.buffer.device_info.model]
        if voice_support then
            if voice_support.cs_voice_support ~= nil then
                info.cs_voice_support = voice_support.cs_voice_support
            end
            if voice_support.volte_support ~= nil then
                info.volte_support = voice_support.volte_support
            end
        end
    end

    local ret = device:send_singleline_command('AT^SYSCFGEX=?', "^SYSCFGEX:")
    if ret then
        local i = 0
        for section in ret:gmatch('%(([A-Z0-9a-z ",/_]-)%)') do
            if i == 0 then
                for word in section:gmatch('([^,]+)') do
                    local mode = word:match('"(%d+)"')
                    if mode == "00" then
                        tinsert(radio_interfaces, { radio_interface = "auto" })
                    elseif mode == "01" then
                        tinsert(radio_interfaces, { radio_interface = "gsm" })
                    elseif mode == "02" then
                        tinsert(radio_interfaces, { radio_interface = "umts" })
                    elseif mode == "03" then
                        tinsert(radio_interfaces, { radio_interface = "lte" })
                    elseif mode == "04" or mode == "05" or mode == "07" then
                        tinsert(radio_interfaces, { radio_interface = "cdma" })
                    end
                end
            elseif (radio_type_supported(radio_interfaces, "gsm") and i == 4) or (not radio_type_supported(radio_interfaces, "gsm") and i == 3) then
                local bands = {}
                for word in section:gmatch('LTE BC(%d+)') do
                    tinsert(bands, word)
                end
                for word in section:gmatch('LTE_B(%d+)') do
                    tinsert(bands, word)
                end
                for word in section:gmatch('LTE(%d+)') do
                    tinsert(bands, word)
                end
                for _, interface in pairs(radio_interfaces) do
                    if interface.radio_interface == "lte" then
                        interface.supported_bands = bands
                    end
                end
            end
            i = i + 1
        end
    else
        ret = device:send_singleline_command('AT^SYSCFG=?', "^SYSCFG:")
        if ret then
            local section = ret:match('%(([A-Z0-9a-z ",/_]-)%)')
            for word in section:gmatch('([^,]+)') do
                local mode = word:match('(%d+)')
                if mode == "2" then
                    tinsert(radio_interfaces, { radio_interface = "auto" })
                elseif mode == "13" then
                    tinsert(radio_interfaces, { radio_interface = "gsm" })
                elseif mode == "14" then
                    tinsert(radio_interfaces, { radio_interface = "umts" })
                end
            end
        end
    end
    if radio_type_supported(radio_interfaces, "lte") then
        info.band_selection_support = "lte"
    end
    info.radio_interfaces = radio_interfaces
    info.supported_auth_types = "none pap chap"
end

function Mapper:get_time_info(device, info)
    local ret = device:send_singleline_command('AT^NWTIME?', "^NWTIME:")
    if ret then
        info.localtime, info.timezone, info.daylight_saving_time = parse_nwtime(ret)
    end
end

function Mapper:get_network_info(device, info)
    helper.merge_tables(info, device.buffer.network_info)
    local ret = device:send_singleline_command('AT^SYSINFOEX', "^SYSINFOEX:")
    if ret then
        local srv_status, srv_domain, roaming_state = ret:match("%^SYSINFOEX:%s?(%d),(%d),(%d)")
        if srv_domain == "1" or srv_domain == "3" then
            info.cs_state = "attached"
        end
        if srv_domain == "2" or srv_domain == "3" then
            info.ps_state = "attached"
        end
        if roaming_state == "0" then
            info.roaming_state = "home"
        else
            info.roaming_state = "roaming"
        end
        if srv_status == "0" then
            info.service_state = "no_service"
        elseif srv_status == "1" then
            info.service_state = "limited_service"
        elseif srv_status == "2" then
            info.service_state = "normal_service"
        elseif srv_status == "3" then
            info.service_state = "limited_regional_service"
        elseif srv_status == "4" then
            info.service_state = "sleeping"
        end
    end
end

local function get_supported_voice_interfaces(device)
    if device.buffer.device_info.model then
        local voice_support = hardcoded_device_capabilities.voice_support[device.buffer.device_info.model]
        if voice_support then
            local ret = device:send_singleline_command('AT^DDSETEX=?', "^DDSETEX:")
            if ret then
                ret = ret:match('%^DDSETEX:%s?%((.-)%)$')
                if ret then
                    local voice_interfaces = {}
                    for port in ret:gmatch('([^,]+)') do
                        tinsert(voice_interfaces, tonumber(port))
                    end
                    return voice_interfaces
                end
            end
        end
    end
    return nil
end

function Mapper:get_device_info(device, info)
    local ret, err = device:send_singleline_command('AT+XTAMR=0', "+XTAMR:")
    if ret then
        local temperature = tonumber(ret:match('+XTAMR:%s?%d+,(%d+)'))
        if temperature then
            info.temperature = temperature / 1000
        end
    elseif err ~= "blacklisted" then
        tinsert(device.command_blacklist, 'AT%+XTAMR=0')
    end

    if not info.temperature then
        ret, err = device:send_singleline_command('AT^CHIPTEMP?', "^CHIPTEMP:")
        if ret then
            local temperature = tonumber(ret:match('%^CHIPTEMP:%s?([%d-]+)'))
            if temperature then
                info.temperature = temperature / 10
            end
        elseif err ~= "blacklisted" then
            tinsert(device.command_blacklist, 'AT%^CHIPTEMP')
        end
    end

    if not device.buffer.device_info.hardware_version then
        ret = device:send_singleline_command('AT^HWVER', "^HWVER:")
        if ret then device.buffer.device_info.hardware_version = ret:match('%^HWVER:%s?"(.-)"') end
    end

    if not device.buffer.device_info.imei_svn then
        ret, err = device:send_singleline_command('AT^IMEISV?', "^IMEISV:")
        if ret then
            device.buffer.device_info.imei_svn = ret:match('%^IMEISV:%s?(.-)$')
        elseif err ~= "blacklisted" then
            tinsert(device.command_blacklist, 'AT%^IMEISV')
        end
    end

    if not device.buffer.device_info.voice_interfaces then
        local ddsetex_interfaces = {
            [2] = {
                name = "diag",
                protocol = 0x3,
                number = 0x1
            }
        }
        local supported_voice_interfaces = get_supported_voice_interfaces(device)
        if supported_voice_interfaces then
            local voice_interfaces = {}
            for _, interface in pairs(supported_voice_interfaces) do
                local huawei_interface = ddsetex_interfaces[interface]
                if huawei_interface then
                    local vp = attty.find_tty_interfaces(device.desc, { protocol = huawei_interface.protocol })
                    if type(vp) == "table" and #vp >= 1 then
                        tinsert(voice_interfaces, { type = "serial", device = vp[1]})
                    else
                        vp = attty.find_tty_interfaces(device.desc, { number = huawei_interface.number })
                        if type(vp) == "table" and #vp >= 1 then
                            tinsert(voice_interfaces, { type = "serial", device = vp[1]})
                        end
                    end
                end
            end
            if #voice_interfaces >= 1 then
                device.buffer.device_info.voice_interfaces = voice_interfaces
            end
        end
    end
end

function Mapper:configure_device(device, config)
    local mode = ""
    local lte_band_mask
    for _, radio in ipairs(config.network.radio_pref) do
        if radio.type == "auto" then
            mode = "00"
            break
        elseif radio.type == "lte" then
            lte_band_mask = helper.get_lte_band_mask(radio.bands)
            mode = mode .. "03"
        elseif radio.type == "umts" then
            mode = mode .. "02"
        elseif radio.type == "gsm" then
            mode = mode .. "01"
        end
    end

    local roaming = 1
    if config.network.roaming == "none" then
        roaming = 0
    end

    local ret
    if lte_band_mask then
        ret = device:send_command(string.format('AT^SYSCFGEX="%s",3fffffff,%d,4,%x,,', mode, roaming, lte_band_mask), 500, 2)
    else
        ret = device:send_command(string.format('AT^SYSCFGEX="%s",3fffffff,%d,4,7fffffffffffffff,,', mode, roaming), 500, 2)
    end

    if not ret then
        local acq_order
        if #config.network.radio_pref == 1 then
            local radio = config.network.radio_pref[1]
            mode = 2
            if radio.type == "gsm" then
                mode = 13
            elseif radio.type == "umts" then
                mode = 14
            end
        else
            mode = 2
            if config.network.radio_pref[1].type == "gsm" then
                acq_order = 1
            else
                acq_order = 2
            end
        end
        device:send_command('AT+CGATT=0', 150000)
        device:send_command(string.format('AT^SYSCFG=%d,%d,3FFFFFFF,%d,4', mode, acq_order or 0, roaming), 500, 2)
    end

    return true
end

local call_ind_states = {
    -- call_originate
    [0] = {
        call_state = "dialing",
        media_state = "normal"
    },
    -- alerting
    [2] = {
        call_state = "delivered",
        media_state = "normal"
    },
    -- connected
    [3] = {
        call_state = "connected",
        media_state = "normal"
    },
    -- released
    [4] = {
        call_state = "disconnected",
        media_state = "no_media"
    },
    -- incoming
    [5] = {
        call_state = "alerting",
        media_state = "no_media"
    },
    -- waiting
    [6] = {
        call_state = "alerting",
        media_state = "no_media"
    },
    -- held
    [7] = {
        call_state = "connected",
        media_state = "held"
    },
    -- retrieve
    [8] = {
        call_state = "connected",
        media_state = "normal"
    }
}

local function get_call_release_cause(key)
    if key == 16 or key == 31 then
        return "normal"
    elseif key == 18 or key == 19 then
        return "no_answer"
    elseif key == 17 then
        return "busy"
    elseif key == 21 then
        return "call_rejected"
    elseif key == 8 or key == 55 then
        return  "barred_call"
    elseif
    key == 3 or
            key == 27 or
            key == 34 or
            key == 38 or
            key == 42 or
            key == 44 or
            key == 47 or
            key == 49 or
            key == 58 or
            key == 63 or
            key == 70 then
        return "resources_unavailable"
    end
    return "other"
end

function Mapper:unsolicited(device, data, sms_data) --luacheck: no unused args
    if helper.startswith(data, "^HCSQ:") then
        return true
    elseif helper.startswith(data, "^MODE:") then
        return true
    elseif helper.startswith(data, "^ECCLIST:") then
        return true
    elseif helper.startswith(data, "^PDPSTATUS:") then
        local reason = data:match("%^PDPSTATUS:%s?(%d+)")
        if reason == "0" then
            device.runtime.log:debug("PDP context deactivated by the network")
        elseif reason == "1" then
            device.runtime.log:debug("PS domain deactivated by the network")
        elseif reason == "2" then
            device.runtime.log:debug("PDP context deactivated by the module")
        end
        return true
    elseif helper.startswith(data, "^SRVST:") then
        local state = data:match("%^SRVST:%s?(%d+)")
        local service_state = "No services"
        if state == "1" then
            service_state = "Restricted services"
        elseif state == "2" then
            service_state = "Valid services"
        elseif state == "3" then
            service_state = "Restricted regional services"
        elseif state == "4" then
            service_state = "Power saving or hibernate state"
        end
        device.runtime.log:debug("Service state changed to " .. service_state)
        return true
    elseif helper.startswith(data, "^NWTIME:") then
        local event_data = {
            event = "time_update_received",
            dev_idx = device.dev_idx
        }
        event_data.localtime, event_data.timezone, event_data.daylight_saving_time = parse_nwtime(data)
        device:send_event("mobiled", event_data)
        return true
    elseif helper.startswith(data, "^EONS:") then
        return true
    elseif helper.startswith(data, "^STIN:") then
        return true
    elseif helper.startswith(data, "^RSSI:") then
        return true
    elseif helper.startswith(data, "^DSFLOWRPT:") then
        parse_dsflowrpt(device, data)
        return true
    elseif helper.startswith(data, "^FOTASTATE:") then
        parse_fotastate(device, data, true)
        return true
    elseif helper.startswith(data, "^NDISSTAT:") or helper.startswith(data, "^NDISSTATEX:") then
        parse_ndisstat(device, data)
        return true
    elseif helper.startswith(data, "^NWNAME:") then
        parse_nwname(device, data)
        return true
    elseif helper.startswith(data, "^LTERSRP:") then
        parse_ltersrp(device, data)
        return true
        -- Some dongles like the E8372 change their CFUN mode when you unlock the SIM
    elseif helper.startswith(data, "^SIMST:") then
        if device.state.powermode == "lowpower" then
            device:send_command('AT+CFUN=0')
        end
        local sim_state = data:match("%^SIMST:%s?(%d+)")
        if sim_state == "1" then
            device.buffer.sim_info = {}
            device:send_event("mobiled", { event = "sim_initialized", dev_idx = device.dev_idx })
        elseif sim_state == "255" then
            device.buffer.sim_info = {}
            device:send_event("mobiled", { event = "sim_removed", dev_idx = device.dev_idx })
        else
            device.buffer.sim_info = {}
            device:send_event("mobiled", { event = "sim_error", dev_idx = device.dev_idx })
        end
        return true
    elseif helper.startswith(data, "^ORIG:") then
        return true
    elseif helper.startswith(data, "^CONF:") then
        return true
    elseif helper.startswith(data, "^CONN:") then
        device:send_command("AT^DDSETEX=2")
        return true
    elseif helper.startswith(data, "^CEND:") then
        local call_id, duration, release_cause_number = data:match("%^CEND:%s?(%d+),(%d+),%d+,(%d+)")
        call_id = tonumber(call_id)
        release_cause_number = tonumber(release_cause_number)
        local release_cause = get_call_release_cause(release_cause_number)

        if call_id and device.calls[call_id] then
            device.calls[call_id].duration = duration
            device.calls[call_id].release_reason = release_cause
        end
        return true
    elseif helper.startswith(data, "^CCALLSTATE:") then
        local call_id, call_status = data:match("%^CCALLSTATE:%s?(%d+),(%d+)")
        call_id = tonumber(call_id)
        call_status = tonumber(call_status)
        if not device.calls[call_id] then
            device.calls[call_id] = {}
        end
        local state = call_ind_states[call_status]
        if state then
            local event = false
            if device.calls[call_id].call_state ~= state.call_state then
                event = true
            end
            device.calls[call_id].call_state = state.call_state
            device.calls[call_id].media_state = state.media_state

            if device.calls[call_id].call_state == "alerting" then
                device.calls[call_id].mmpbx_call_id = device.mmpbx_call_id_counter
                device.mmpbx_call_id_counter = device.mmpbx_call_id_counter + 1
                device.calls[call_id].direction = "incoming"
            end

            -- Insert CLIP if we have any
            local remote_party, number_format
            if call_status == 5 and device.clip then
                remote_party = device.clip.remote_party
                number_format = device.clip.number_format
                device.clip = nil
            end

            if event then
                device:send_event("mobiled.voice", {
                    event = "call_state_changed",
                    call_id = device.calls[call_id].mmpbx_call_id,
                    dev_idx = device.dev_idx,
                    call_state = device.calls[call_id].call_state,
                    reason = device.calls[call_id].release_reason,
                    remote_party = remote_party,
                    number_format = number_format
                })
            end
            -- Remove call info when released
            if call_status == 4 then
                device.calls[call_id] = nil
            end
        end
        return true
    elseif helper.startswith(data, "+CLIP:") then
        local remote_party, number_type = data:match('%+CLIP:%s?"([%d+]+)",(%d+)')
        if remote_party then
            device.clip = { remote_party = remote_party, number_format = voice.clcc_number_type[number_type] }
        end
        return true
    end
    return nil
end

function Mapper:debug(device)
    local ret = device:send_singleline_command('AT^SYSCFGEX?', '^SYSCFGEX:')
    if ret then tinsert(device.debug.device_state, ret) end
    ret = device:send_singleline_command('AT^SYSCFG?', '^SYSCFG:')
    if ret then tinsert(device.debug.device_state, ret) end
    ret = device:send_singleline_command('AT^SYSCFG=?', '^SYSCFG:')
    if ret then tinsert(device.debug.device_state, ret) end
    ret = device:send_singleline_command('AT+CFUN?', '+CFUN:')
    if ret then tinsert(device.debug.device_state, ret) end
    ret = device:send_singleline_command('AT^SYSCFGEX=?', '^SYSCFGEX:')
    if ret then tinsert(device.debug.device_state, ret) end
    ret = device:send_singleline_command('AT^DIALMODE?', '^DIALMODE:')
    if ret then tinsert(device.debug.device_state, ret) end
    ret = device:send_singleline_command('AT^SYSINFO', '^SYSINFO:')
    if ret then tinsert(device.debug.device_state, ret) end
    ret = device:send_singleline_command('AT^SYSINFOEX', '^SYSINFOEX:')
    if ret then tinsert(device.debug.device_state, ret) end
    ret = device:send_singleline_command('AT^DHCP?', '^DHCP:')
    if ret then tinsert(device.debug.device_state, ret) end
    ret = device:send_singleline_command('AT^CPULOAD?', '^CPULOAD:')
    if ret then tinsert(device.debug.device_state, ret) end
    ret = device:send_singleline_command('AT^FOTACFG?', '^FOTACFG:')
    if ret then tinsert(device.debug.device_state, ret) end
    ret = device:send_singleline_command('AT^FOTASTATE?', '^FOTASTATE:')
    if ret then tinsert(device.debug.device_state, ret) end
    ret = device:send_singleline_command('AT^FOTAMODE?', '^FOTAMODE:')
    if ret then tinsert(device.debug.device_state, ret) end
    ret = device:send_multiline_command('AT^NDISSTATQRY?', '^NDISSTATQRY:')
    if ret then
        for _, line in pairs(ret) do
            tinsert(device.debug.device_state, line)
        end
    end
    return true
end

function Mapper:init_device(device)
    if not device.state.initialized then
        device:send_command("AT^CURC=1")
        device:send_command("AT^SIMST=1")
        device:send_command("AT+COLP=1")
        device:send_command("AT+CLIP=1")
        device:send_command("AT+CHUP")
        device.buffer.firmware_upgrade_info = { status = "not_running" }
        local info = firmware_upgrade.get_state()
        if info then
            device.buffer.firmware_upgrade_info = info
        end
        firmware_upgrade.reset_state()
    end
    return true
end

function Mapper:destroy_device(device)
    -- Disable notifications
    device:send_command("AT^CURC=0")
    return true
end

function Mapper:firmware_upgrade(device, path)
    if not path then
        device.buffer.firmware_upgrade_info.status = "invalid_parameters"
        return nil, "Invalid parameters"
    end

    local parts = {}
    for part in path:gmatch('([^,]+)') do
        tinsert(parts, part)
    end

    local apn = parts[1]
    local username = parts[2]
    local password = parts[3]
    if not apn then
        device.buffer.firmware_upgrade_info.status = "invalid_parameters"
        return nil, "Invalid parameters"
    end

    device:send_command("AT^FOTADL=0")
    device.buffer.firmware_upgrade_info = { status = "started" }
    firmware_upgrade.reset_state()

    -- In order to pass past FOTA state 40, any data session should be terminated
    device:send_command('AT^NDISDUP=1,0', 5000)

    device:send_command(string.format('AT^FOTACFG="%s",%s,%s,0', apn, username or "", password or ""))
    device:send_command("AT^FOTAMODE=0,1,1,1")
    device:send_command("AT^FOTADET")
    return true
end

function Mapper:get_firmware_upgrade_info(device)
    if device.buffer.firmware_upgrade_info.status ~= "invalid_parameters" then
        local ret = device:send_singleline_command('AT^FOTASTATE?', '^FOTASTATE:')
        if ret then parse_fotastate(device, ret, false) end
    end
    return device.buffer.firmware_upgrade_info
end

function Mapper:network_scan(device, start)
    if start then
        helper.sleep(5)
        device:send_command("AT+CFUN=0")
        helper.sleep(2)
        device:send_command("AT+CFUN=1")
    end
    return true
end

function Mapper:end_call(device, call_id) --luacheck: no unused args
    return device:send_command("AT+CHUP")
end

function Mapper:call_info(device, call_id)
    call_id = tonumber(call_id)

    if call_id and device.calls[call_id] then
        local ret = device:send_singleline_command(string.format("AT^CDUR=%d", call_id), "^CDUR:")
        if ret then
            device.calls[call_id].duration = ret:match("%^CDUR:%s?%d+,(%d+)")
        end
    else
        for _, call in pairs(device.calls) do
            if call.call_id then
                local ret = device:send_singleline_command(string.format("AT^CDUR=%d", call.call_id), "^CDUR:")
                if ret then
                    call.duration = ret:match("%^CDUR:%s?%d+,(%d+)")
                end
            end
        end
    end

    if call_id then
        return device.calls[call_id] or {}
    end
    return device.calls or {}
end

function Mapper:multi_call(device, call_id, action, second_call_id) --luacheck: no unused args
    return nil, "Unsupported multi_call action"
end

function Mapper:supplementary_service(device, service, action, params, forwarding_type, forwarding_number) --luacheck: no unused args
    local ret
    if service == "call_waiting" then
        if action == "activate" then
            device:send_command("AT+CCWA=1,1,1")
            return true
        elseif action == "deactivate" then
            device:send_command("AT+CCWA=1,0,1")
            return true
        elseif action == "query" then
            ret = device:send_singleline_command("AT+CCWA=1,2,1", "+CCWA:", 60000)
            if ret then
                local status = ret:match("+CCWA:%s?(%d)")
                if status == "1" then
                    return { status = "activated" }
                end
            end
            return { status = "deactivated" }
        end
        return nil, "Invalid action"
    elseif service == "clip" then
        if action == "activate" then
            device:send_command("AT+CLIP=1")
            return true
        elseif action == "deactivate" then
            device:send_command("AT+CLIP=0")
            return true
        elseif action == "query" then
            ret = device:send_singleline_command("AT+CLIP?", "+CLIP:", 60000)
            local info = {
                status = "unknown",
                enabled = false
            }
            if ret then
                local enabled, status = ret:match("+CLIP:%s?(%d),(%d)")
                if enabled == "1" then
                    info.enabled = true
                end
                if status == "0" then
                    info.status = "unavailable"
                elseif status == "1" then
                    info.status = "available"
                end
            end
            return info
        end
        return nil, "Invalid action"
    elseif service == "clir" then
        if action == "activate" then
            device:send_command("AT+CLIR=1")
            return true
        elseif action == "deactivate" then
            device:send_command("AT+CLIR=0")
            return true
        elseif action == "query" then
            ret = device:send_singleline_command("AT+CLIR?", "+CLIR:", 60000)
            local info = {
                status = "unknown",
                enabled = false
            }
            if ret then
                local enabled, status = ret:match("+CLIR:%s?(%d),(%d)")
                if enabled == "1" then
                    info.enabled = true
                end
                if status == "0" then
                    info.status = "unavailable"
                elseif status == "1" then
                    info.status = "available"
                elseif status == "3" then
                    info.status = "temporarily_unavailable"
                elseif status == "4" then
                    info.status = "temporarily_available"
                end
            end
            return info
        end
        return nil, "Invalid action"
    elseif service == "colp" then
        if action == "activate" then
            device:send_command("AT+COLP=1")
            return true
        elseif action == "deactivate" then
            device:send_command("AT+COLP=0")
            return true
        elseif action == "query" then
            ret = device:send_singleline_command("AT+COLP?", "+COLP:", 60000)
            local info = {
                status = "unknown",
                enabled = false
            }
            if ret then
                local enabled, status = ret:match("+COLP:%s?(%d),(%d)")
                if enabled == "1" then
                    info.enabled = true
                end
                if status == "0" then
                    info.status = "unavailable"
                elseif status == "1" then
                    info.status = "available"
                end
            end
            return info
        end
        return nil, "Invalid action"
    elseif service == "call_forwarding" then
        local forwarding_translation = {
            ["unconditional"] = 0,
            ["busy"] = 1,
            ["no_reply"] = 2,
            ["unreachable"] = 3,
            ["all_types"] = 4,
            ["all_conditional_types"] = 5
        }

        if action == "activate" then
            local number_type = "129"
            if params.forwarding_number_type == "international" then
                number_type = "145"
            end
            device:send_command(string.format('AT+CCFC=%d,1,"%s",%d', forwarding_translation[params.forwarding_type], params.forwarding_number, number_type))
            return true
        elseif action == "deactivate" then
            device:send_command("AT+CCFC=0")
            return true
        elseif action == "query" then
            ret = device:send_singleline_command(string.format("AT+CCFC=%d,2", forwarding_translation[params.forwarding_type]), "+CCFC:", 60000)
            local info = {
                enabled = false
            }
            if ret then
                local enabled = ret:match('+CCFC:%s?(%d)')
                if enabled == "1" then
                    info.enabled = true
                end
            end
            return info
        end
        return nil, "Invalid action"
    end
    return nil, "Invalid service"
end

function Mapper:get_network_interface(device, session_id)
    if device.product == "K4305" then
        if device.network_interfaces and session_id == 1 then
            return device.network_interfaces[1]
        end
    end
end

function Mapper:set_power_mode(device, mode)
    if mode == "lowpower" or mode == "airplane" then
        device.buffer.session_info = {}
        device.buffer.network_info = {}
        device.buffer.radio_signal_info = {}
    else
        device:send_command('AT^RFSWITCH=1', 5000)
    end
    return true
end

function M.create(runtime, device) --luacheck: no unused args
    local mapper = {
        mappings = {
            set_attach_params = "override",
            get_network_interface = "override",
            configure_device = "runfirst",
            get_session_info = "override",
            start_data_session = "override",
            stop_data_session = "override",
            firmware_upgrade = "override",
            get_firmware_upgrade_info = "override",
            network_scan = "runfirst",
            supplementary_service = "override",
            multi_call = "override",
            dial = "override",
            end_call = "override",
            destroy_device = "runfirst"
        }
    }

    local modem_ports = attty.find_tty_interfaces(device.desc, { class = 0xff, subclass = 0x1, protocol = 0x1 })
    modem_ports = modem_ports or attty.find_tty_interfaces(device.desc, { class = 0xff, subclass = 0x2, protocol = 0x1 })
    modem_ports = modem_ports or attty.find_tty_interfaces(device.desc, { class = 0xff, subclass = 0x2, protocol = 0x31 })
    modem_ports = modem_ports or attty.find_tty_interfaces(device.desc, { class = 0xff, subclass = 0x2, protocol = 0x10 })
    modem_ports = modem_ports or attty.find_tty_interfaces(device.desc, { class = 0xff, subclass = 0x6, protocol = 0x10 })
    modem_ports = modem_ports or attty.find_tty_interfaces(device.desc, { class = 0x2, subclass = 0x2, protocol = 0xff, number = 0x0 })

    local pcui_ports = attty.find_tty_interfaces(device.desc, { class = 0xff, subclass = 0x1, protocol = 0x16 })
    pcui_ports = pcui_ports or attty.find_tty_interfaces(device.desc, { class = 0x2, subclass = 0x6, protocol = 0x0 })
    pcui_ports = pcui_ports or attty.find_tty_interfaces(device.desc, { class = 0x2, subclass = 0xd, protocol = 0x0 })
    pcui_ports = pcui_ports or attty.find_tty_interfaces(device.desc, { class = 0xff, subclass = 0x1, protocol = 0x2 })
    pcui_ports = pcui_ports or attty.find_tty_interfaces(device.desc, { class = 0xff, subclass = 0x2, protocol = 0x2 })
    pcui_ports = pcui_ports or attty.find_tty_interfaces(device.desc, { class = 0xff, subclass = 0x2, protocol = 0x32 })
    pcui_ports = pcui_ports or attty.find_tty_interfaces(device.desc, { class = 0xff, subclass = 0x2, protocol = 0x12 })
    pcui_ports = pcui_ports or attty.find_tty_interfaces(device.desc, { class = 0xff, subclass = 0x6, protocol = 0x12 })
    pcui_ports = pcui_ports or attty.find_tty_interfaces(device.desc, { class = 0xff, subclass = 0x3, protocol = 0x2 })

    modem_ports = modem_ports or attty.find_tty_interfaces(device.desc, { class = 0xff, subclass = 0xff, protocol = 0xff, number = 0x0 })
    pcui_ports = pcui_ports or attty.find_tty_interfaces(device.desc, { class = 0xff, subclass = 0xff, protocol = 0xff, number = 0x4 })
    pcui_ports = pcui_ports or attty.find_tty_interfaces(device.desc, { class = 0xff, subclass = 0xff, protocol = 0xff, number = 0x3 })
    pcui_ports = pcui_ports or attty.find_tty_interfaces(device.desc, { class = 0xff, subclass = 0xff, protocol = 0xff, number = 0x2 })
    pcui_ports = pcui_ports or attty.find_tty_interfaces(device.desc, { class = 0xff, subclass = 0xff, protocol = 0xff, number = 0x1 })

    if device.product == "K4305" then
        pcui_ports = attty.find_tty_interfaces(device.desc, { class = 0x2, subclass = 0x2, protocol = 0xff, number = 0x2 })
    elseif device.product == "K5150" then
        pcui_ports = attty.find_tty_interfaces(device.desc, { class = 0xff, subclass = 0x2, protocol = 0x12, number = 0x2 })
    end

    device.default_interface_type = "pcui"

    if modem_ports then
        for _, port in pairs(modem_ports) do
            tinsert(device.interfaces, { port = port, type = "modem" })
        end
    end

    if pcui_ports then
        for _, port in pairs(pcui_ports) do
            tinsert(device.interfaces, { port = port, type = "pcui" })
        end
    end

    -- The default case is NDIS dongles. Here we handle the PPP dongles
    if device.pid == "1001" -- E3351
            or device.pid == "1003" -- E156G E17X
            or device.pid == "1c05" then -- E173
        device.sessions[1] = { proto = "ppp" }
    end

    -- Vodafone K4305 3G dongle supporting two PDNs
    if device.product == "K4305" then
        device.sessions = {
            { proto = "ppp" },
            { proto = "dhcp" }
        }
    end

    setmetatable(mapper, Mapper)
    return mapper
end

return M
