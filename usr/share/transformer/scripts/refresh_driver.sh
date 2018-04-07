sleep 7

installed_driver=$(transformer-cli get rpc.xdsl.dslversion | awk '{print $4}')
driver_set=$(uci get env.var.driver_version)

if [ $installed_driver != $driver_set ]; then
	logger "Downloading driver "$driver_set
	wget https://repository.ilpuntotecnicoeadsl.com/files/Ansuel/AGTEF/adsl_driver/$driver_set -O /tmp/
	mv /tmp/$driver_set /etc/adsl/adsl_phy.bin
	logger "Restarting xdslctl"
	xdslctl stop
	/etc/init.d/xdsl start
fi
