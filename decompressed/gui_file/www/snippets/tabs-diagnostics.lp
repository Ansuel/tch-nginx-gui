--pretranslated: do not change this file

gettext.textdomain('webui-core')

local getProxy = require("datamodel").get
local tinsert = table.insert

local items = {
    {"diagnostics-ping-modal.lp", T"Ping & Traceroute"},
    {"diagnostics-connection-modal.lp", T"Connection"},
    {"diagnostics-network-modal.lp", T"Network"},
	{"diagnostics-leds-modal.lp", T"Leds"},
    {"diagnostics-igmpproxy-modal.lp", T"Igmpproxy"},
    {"port-mirror-modal.lp", T"Port Mirror"},
    {"diagnostics-tcpdump-modal.lp", T"Tcpdump"},
}

if require("lfs").attributes("/etc/config/xdsl", "mode") == "file" then
    local dsl_status = getProxy("sys.class.xdsl.@line0.Enable")

    if dsl_status and dsl_status[1].value == "1" then
        tinsert(items, 1, {"diagnostics-xdsl-modal.lp", T"xDSL"} )
		tinsert(items, 2, {"diagnostics-xdsl-graphics-modal.lp", T"xDSL Graphics"} )
    end
end

require("sharedModalTabHelper").createModalTab(items)