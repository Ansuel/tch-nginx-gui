--pretranslated: do not change this file

gettext.textdomain('webui-core')

local items = {
    {"usermgr-modal.lp", T"User Manager"},
    {"system-init-modal.lp", T"Init Management"},
    {"system-cron-modal.lp", T"Cron Management"},
    {"logviewer-modal.lp", T"Log Viewer"},
    {"log-routingtable-modal.lp", T"Routing Table"},
    {"log-connections-modal.lp", T"Connections"},
	{"modem-stats-modal.lp", T"Modem Stats Graph"},
}

require("sharedModalTabHelper").createModalTab(items)