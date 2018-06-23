#!/bin/sh /etc/rc.common

USE_PROCD=1

process_diagnosticsstate() {
	instance_name="${1}"

	# Get the diagnosticsstate value
	config_get diagnosticsstate "$1" state

	# If diagnostics state is Requested, start the process
	if [ "$diagnosticsstate" = "Requested" ]; then
		# Start a fresh process
		procd_open_instance $instance_name
		procd_set_param command /usr/sbin/intfdiag $1
		procd_close_instance
	fi
}

start_service() {
	# Load intfdiag config
	config_load intfdiag
	# Iterate over all sections
	config_foreach process_diagnosticsstate intfdiag
}
