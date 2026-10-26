--pretranslated: do not change this file

gettext.textdomain('webui-core')

local items = {
    {"wireless-modal.lp",T"Wireless"},
    {"tod_wireless-modal.lp",T"Wireless Time Control"},
}

require("sharedModalTabHelper").createModalTab(items)
