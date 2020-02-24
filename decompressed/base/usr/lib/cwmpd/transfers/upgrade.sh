#!/bin/sh

# tch-nginx-gui policy: override stock upgrade.sh cwmp handler

# cwmp remote upgrade intecepted:
#   do not apply any upgrade, save download url in uci, alert user about firmware upgrade available in gui

exit 1