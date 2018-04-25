wanmode=$(uci get -q network.config.wan_mode)
connectivity="yes"
if ping -q -c 1 -W 1 8.8.8.8 >/dev/null; then
  connectivity="yes"
else
  connectivity="no"
fi

sleep 7

installed_driver=$(transformer-cli get rpc.xdsl.dslversion | awk '{print $4}')
driver_set=$(uci get env.var.driver_version)

if [ "$wanmode" != "bridge" ] && [ $connectivity == "yes" ]; then
	if [ $installed_driver != $driver_set ]; then
		logger "Downloading driver "$driver_set
		wget -O /tmp/$driver_set https://repository.ilpuntotecnicoeadsl.com/files/Ansuel/AGTEF/adsl_driver/$driver_set
		mv /tmp/$driver_set /etc/adsl/adsl_phy.bin
		logger "Restarting xdslctl"
		xdslctl stop
		/etc/init.d/xdsl start
	fi
fi
