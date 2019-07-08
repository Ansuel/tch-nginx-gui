local ubus, uloop = require('ubus'), require('uloop')
local netlink = require("tch.netlink")
local format = string.format
local syslog = require("syslog")

local M = {}

syslog.openlog("ledfw", syslog.options.LOG_PID, syslog.facilities.LOG_DAEMON)

function M.start(cb)
    uloop.init()
    local conn = ubus.connect()
    if not conn then
        error("Failed to connect to ubusd")
    end

    local events = {}
    events['network.interface'] = function(msg)
        if msg ~= nil and msg.interface ~= nil then
            if msg.action ~= nil then
               cb('network_interface_' .. msg.interface:gsub('[^%a%d_]','_') .. '_' .. msg.action:gsub('[^%a%d_]','_'))
            end
            if msg.interface:match('^wan6?$') ~= nil then
               if (msg['ipv4-address'] ~= nil or msg['ipv6-address'] ~= nil) then
                  if (msg['ipv4-address'] == nil or msg['ipv4-address'][1] == nil) and (msg['ipv6-address'] == nil or msg['ipv6-address'][1]== nil) then
                     cb('network_interface_' .. msg.interface .. '_no_ip')
                  end
               end
            end
            if msg.pppinfo ~= nil  and msg.pppinfo.pppstate ~= nil then
               cb('network_interface_' .. msg.interface:gsub('[^%a%d_]','_') .. '_ppp_' .. msg.pppinfo.pppstate:gsub('[^%a%d_]','_'))
            end
        end
    end

    events['network.mproxy'] = function(msg)
        if msg ~=nil and msg.state ~=nil then
            if msg.state == "started" then
               cb('mptcp_on')
            elseif msg.state == "stopped" then
               cb('mptcp_off')
            end
        end
    end

    events['network.lte_backup'] = function(msg)
        if msg ~=nil and msg.state ~=nil then
            if msg.state == "enabled" then
               cb('backup_on')
            elseif msg.state == "disabled" then
               cb('backup_off')
            end
        end
    end

--Prepare for later use (PXM and MPTCP)
    events['network.neigh'] = function(msg)
        if msg ~=nil and msg.interface ~=nil and msg.interface == "eth4" then
            if msg.action == "add" then
--               cb('net_neigh_dummy')
            end
        end
    end

    events['hostmanager.devicechanged'] = function(msg)
        if msg ~=nil and msg.l3interface ~=nil and msg.l3interface == "vlan_voip_mgmt" then
            if msg.state == "disconnected" then
--               cb('hostman_voip_down')
            end
        end
    end

    events['power'] = function(msg)
        if msg ~= nil and msg.state ~= nil then
            cb('power_' .. msg.state)
        end
    end

    events['xdsl'] = function(msg)
        if msg ~= nil then
            cb('xdsl_' .. msg.statuscode)
        end
    end

    events['gpon.ploam'] = function(msg)
        if msg ~= nil and msg.statuscode ~= nil then
	    if msg.statuscode ~= 5 then
               cb('gpon_ploam_' .. msg.statuscode)
	    else
               cb('gpon_ploam_50')
            end
        end
    end

    events['gpon.omciport'] = function(msg)
        if msg ~= nil and msg.statuscode ~= nil then
            cb('gpon_ploam_' .. 5 .. msg.statuscode)
        end
    end


    events['gpon.rfo'] = function(msg)
        if msg ~= nil and msg.statuscode ~= nil then
            cb('gpon_rfo_' .. msg.statuscode)
        end
    end

    events['usb.usb_led'] = function(msg)
        if msg ~= nil and msg.status ~= nil then
            cb('usb_led_' .. msg.status)
        end
    end

    events['voice'] = function(msg)
        if msg ~= nil and msg.state ~= nil then
            cb('voice_' .. msg.state)
        end
    end

    events['mmpbx.devicelight'] = function(msg)
        if msg ~= nil and msg.fxs_dev_0 ~= nil then
            cb('voice1_' .. msg.fxs_dev_0)
        end
        if msg ~= nil and msg.fxs_dev_1 ~= nil then
            cb('voice2_' .. msg.fxs_dev_1)
        end
    end

    events['mmpbxbrcmdect.registration'] = function(msg)
        if msg ~= nil then
            cb('dect_registration_' .. tostring(msg.open))
        end
    end

    events['mmpbxbrcmdect.registered'] = function(msg)
        if msg ~= nil then
            cb('dect_registered_' .. tostring(msg.present))
        end
    end

    events['mmpbxbrcmdect.paging'] = function(msg)
        if msg ~= nil then
            if msg.alerting == true then
                cb('paging_alerting_true')
            else
                cb('paging_alerting_false')
            end
        end
    end

    events['mmpbxbrcmdect.callstate'] = function(msg)
        if msg ~= nil then
            if ((msg.dect_dev_0.activeLinesNumber == 1) or
                (msg.dect_dev_1.activeLinesNumber == 1) or
                (msg.dect_dev_2.activeLinesNumber == 1) or
                (msg.dect_dev_3.activeLinesNumber == 1) or
                (msg.dect_dev_4.activeLinesNumber == 1) or
                (msg.dect_dev_5.activeLinesNumber == 1)) then
                cb('dect_active')
            else
                cb('dect_inactive')
            end
        end
    end

    events['wireless.wps_led'] = function(msg)
        if msg ~= nil and msg.wps_state ~= nil then
            cb('wifi_wps_' .. msg.wps_state)
        end
    end

    events['qeo.power_led'] = function(msg)
        if msg ~= nil and msg.state ~= nil then
            cb('qeo_reg_' .. msg.state)
        end
    end

    events['wireless.wlan_led'] = function(msg)
        if msg ~= nil then
            if msg.radio_oper_state == 1 and msg.bss_oper_state == 1 then
                if msg.acl_state == 1 then
                   cb("wifi_acl_on_" .. msg.ifname)
                else
                   cb("wifi_acl_off_" .. msg.ifname)
                   cb("wifi_security_" .. msg.security .. "_" .. msg.ifname)
                   if msg.sta_connected == 0 then
                      cb("wifi_no_sta_con_" .. msg.ifname)
                   else
                      cb("wifi_sta_con_" .. msg.ifname)
                   end
                end
            else
                if msg.radio_oper_state == 0 and msg.bss_oper_state == 0 then
                   cb("wifi_state_off_" .. msg.ifname)
                end
            end
        end
    end

    events['infobutton'] = function(msg)
        if msg ~= nil and msg.state ~= nil then
            cb("infobutton_state_" .. msg.state)
        end
    end

    events['statusled'] = function(msg)
        if msg ~= nil and msg.state ~= nil then
            cb("status_" .. msg.state)
        end
    end

    events['fwupgrade'] = function(msg)
        if msg ~= nil and msg.state ~= nil then
			--restore default function of this... WHY TELECOM CHANGE EVERYTHING JUST WHY
			cb("fwupgrade_state_" .. msg.state)
            --if msg.state == "upgrading" or msg.state == "flashing" then
            --    cb("remote_mgmt_session_begins")
            --elseif msg.state == "done" or msg.state == "failed" then
            --    cb("remote_mgmt_session_ends")
            --end
        end
    end

    events['cwmpd'] = function(msg)
        if msg ~= nil and msg.session ~= nil then
            cb("remote_mgmt_session_" .. msg.session)
        end
    end

    events['cwmpd.transfer'] = function(msg)
        if msg ~= nil and msg.session ~= nil then
            cb("remote_mgmt_session_" .. msg.session)
        end
    end

    events['event'] = function(msg)
        if msg ~= nil and msg.state ~= nil then
            cb(msg.state)
        end
    end

    events['mmpbx.callstate'] = function(msg)
        if msg ~= nil and msg.profileType == "MMNETWORK_TYPE_SIP" and msg.profileUsable == true then
            cb("callstate_" .. msg.reason .. "_" .. msg.device)
        end
    end

    events['mmpbx.mediastate'] = function(msg)
        if msg and (msg.mediaState == "MMPBX_MEDIASTATE_NORMAL") then
            cb(format("mediastate_%s_%s", msg.mediaState, msg.device))
	end
    end

    events['mmbrcmfxs.callstate'] = function(msg)
    if msg ~= nil then
            if (msg.fxs_dev_0.activeLinesNumber > 0 )  then
                cb('fxs_line1_active')
            else
                cb('fxs_line1_inactive')
            end
            if (msg.fxs_dev_1.activeLinesNumber > 0)  then
                cb('fxs_line2_active')
            else
                cb('fxs_line2_inactive')
            end
    if ((msg.fxs_dev_0.activeLinesNumber > 0) or
        (msg.fxs_dev_1.activeLinesNumber > 0)) then
            cb('fxs_active')
    else
            cb('fxs_inactive')
    end
    end
    end
        events['mmpbx.voiceled.status'] = function(msg)
        if msg ~= nil then
            if msg.fxs_dev_0 == "NOK" then
                cb('fxs_line1_error')
            elseif  msg.fxs_dev_0 == "OK-OFF" then
                cb('fxs_line1_off')
            elseif  msg.fxs_dev_0 == "IDLE" then
                cb('fxs_line1_off')
            else
                cb('fxs_line1_usable')
            end
            if msg.fxs_dev_1 == "NOK" then
                cb('fxs_line2_error')
            elseif  msg.fxs_dev_1 == "OK-OFF" then
                cb('fxs_line2_off')
            elseif  msg.fxs_dev_1 == "IDLE" then
                cb('fxs_line2_off')
            else
                cb('fxs_line2_usable')
            end
            if ((msg.fxs_dev_0 == "NOK") or (msg.fxs_dev_1 == "NOK")) then
                 cb('fxs_lines_error')
             elseif ((msg.fxs_dev_0 == "OK-OFF" and msg.fxs_dev_1 == "OK-OFF") or (msg.fxs_dev_0 == "OK-OFF" and msg.fxs_dev_1 == nil) or (msg.fxs_dev_1 == "OK-OFF" and msg.fxs_dev_0 == nil)) then
               cb('fxs_lines_usable_off')
             elseif msg.fxs_dev_0 == "IDLE" then
               cb('fxs_lines_usable_off')
            else
               cb('fxs_lines_usable')
            end
        end
    end

    events['mmpbx.dectled.status'] = function(msg)
        if msg ~= nil then
            if msg.dect_dev ~= nil then
                cb('dect_' .. msg.dect_dev)
            end
        end
    end

    conn:listen(events)

    --register for netlink events
    local nl,err = netlink.listen(function(dev, status)
        if status then
            cb('network_device_' .. dev .. '_up')
        else
            cb('network_device_' .. dev .. '_down')
        end
    end)
    if not nl then
        error("Failed to register with netlink" .. err)
    end

    uloop.run()
end

return M
