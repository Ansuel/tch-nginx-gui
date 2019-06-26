--pretranslated: do not change this file

gettext.textdomain('webui-core')

local items = {
    {"wanservices-modal.lp", T"Port Forward"},
    {"upnp-modal.lp", T"UPnP"},
    {"wol-modal.lp", T"WoL / WoW"},
	{"customdns-modal.lp", T"Custom DNS"},
	{"dyndns-modal.lp", T"DDNS"},
	{"dmz-modal.lp", T"DMZ"},
}

require("sharedModalTabHelper").createModalTab(items)