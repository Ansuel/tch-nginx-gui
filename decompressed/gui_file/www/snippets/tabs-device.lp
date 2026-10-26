--pretranslated: do not change this file

gettext.textdomain('webui-core')

local items = {
    {"device-modal.lp", T"Devices List"},
    {"hostmap-modal.lp", T"Devices Map"},
    {"wifi-nurse-modal.lp", T"WiFi Nurse"},
	{"traffic-monitor.lp", T"Traffic Monitor"},
}

require("sharedModalTabHelper").createModalTab(items)