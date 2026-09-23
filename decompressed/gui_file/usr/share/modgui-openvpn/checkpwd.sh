#!/bin/sh

password_file="/etc/openvpn/psw-file"
[ -r "$password_file" ] || exit 1
[ -n "$username" ] || exit 1

expected="$(awk -v user="$username" '$1 == user { print $2; exit }' "$password_file")"
[ -n "$expected" ] && [ "$password" = "$expected" ]
