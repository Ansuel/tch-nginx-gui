#!/bin/sh

# This is a helper script to allow users to safely execute a password update from Lua,
# by fork() and execv().
#
# setClashPassw.lua is its main user.

. /lib/functions/provision.sh

set_pass "$@"
