--pretranslated: do not change this file

gettext.textdomain('webui-core')

local items = {
    {"usermgr-modal.lp", T"User Manager"},
    {"logviewer-modal.lp", T"Log Viewer"},
    {"log-routingtable-modal.lp", T"Routing Table"},
    {"log-connections-modal.lp", T"Connections"},
	{"modem-stats-modal.lp", T"Modem Stats Graph"},
}

require("sharedModalTabHelper").createModalTab(items)