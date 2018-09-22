add_new_web_rule() {
	if [ ! $(uci get -q web.broadband.target) ]; then
		uci set web.broadband=rule
		uci set web.broadband.target='/broadband.lp'
		uci add_list web.broadband.roles='admin' 
		uci add_list web.broadband.roles='engineer'
		uci add_list web.ruleset_main.rules='broadband'
    fi
	if [ ! $(uci get -q web.contentsharing_refresh) ]; then
		uci set web.contentsharing_refresh=rule
		uci set web.contentsharing_refresh.target='/contentsharing.lp'
		uci add_list web.contentsharing_refresh.roles='admin' 
		uci add_list web.contentsharing_refresh.roles='engineer'
		uci add_list web.ruleset_main.rules='contentsharing_refresh'
    fi
	if [ ! $(uci get -q web.device) ]; then
		uci set web.device=rule
		uci set web.device.target='/device.lp'
		uci add_list web.device.roles='admin' 
		uci add_list web.device.roles='engineer'
		uci add_list web.ruleset_main.rules='device'
    fi
	if [ ! $(uci get -q web.dyndns) ]; then
		uci set web.dyndns=rule
		uci set web.dyndns.target='/dyndns.lp'
		uci add_list web.dyndns.roles='admin' 
		uci add_list web.dyndns.roles='engineer'
		uci add_list web.ruleset_main.rules='dyndns'
    fi
	if [ ! $(uci get -q web.home) ]; then
		uci set web.home=rule
		uci set web.home.target='/home.lp'
		uci add_list web.home.roles='admin' 
		uci add_list web.home.roles='engineer'
		uci add_list web.ruleset_main.rules='home'
    fi
	if [ ! $(uci get -q web.parental) ]; then
		uci set web.parental=rule
		uci set web.parental.target='/parental-modal.lp'
		uci add_list web.parental.roles='admin' 
		uci add_list web.parental.roles='engineer'
		uci add_list web.ruleset_main.rules='parental'
    fi
	if [ ! $(uci get -q web.portforwarding) ]; then
		uci set web.portforwarding=rule
		uci set web.portforwarding.target='/portforwarding.lp'
		uci add_list web.portforwarding.roles='admin' 
		uci add_list web.portforwarding.roles='engineer'
		uci add_list web.ruleset_main.rules='portforwarding'
    fi
	if [ ! $(uci get -q web.remoteaccess) ]; then
		uci set web.remoteaccess=rule
		uci set web.remoteaccess.target='/remoteaccess.lp'
		uci add_list web.remoteaccess.roles='admin' 
		uci add_list web.remoteaccess.roles='engineer'
		uci add_list web.ruleset_main.rules='remoteaccess'
    fi
	if [ ! $(uci get -q web.tod) ]; then
		uci set web.tod=rule
		uci set web.tod.target='/tod.lp'
		uci add_list web.tod.roles='admin' 
		uci add_list web.tod.roles='engineer'
		uci add_list web.ruleset_main.rules='tod'
    fi
	if [ ! $(uci get -q web.traffic) ]; then
		uci set web.traffic=rule
		uci set web.traffic.target='/traffic.lp'
		uci add_list web.traffic.roles='admin' 
		uci add_list web.traffic.roles='engineer'
		uci add_list web.ruleset_main.rules='traffic'
    fi
	if [ ! $(uci get -q web.user) ]; then
		uci set web.user=rule
		uci set web.user.target='/user.lp'
		uci add_list web.user.roles='admin' 
		uci add_list web.user.roles='engineer'
		uci add_list web.ruleset_main.rules='user'
    fi
	if [ ! $(uci get -q web.wifi) ]; then
		uci set web.wifi=rule
		uci set web.wifi.target='/wifi.lp'
		uci add_list web.wifi.roles='admin' 
		uci add_list web.wifi.roles='engineer'
		uci add_list web.ruleset_main.rules='wifi'
    fi
	if [ ! $(uci get -q web.wifiguest) ]; then
		uci set web.wifiguest=rule
		uci set web.wifiguest.target='/wifiguest.lp'
		uci add_list web.wifiguest.roles='admin' 
		uci add_list web.wifiguest.roles='engineer'
		uci add_list web.ruleset_main.rules='wifiguest'
    fi
	if [ ! $(uci get -q web.helpbroadband) ]; then
		uci set web.helpbroadband=rule
		uci set web.helpbroadband.target='/helpfiles/help_broadband.lp'
		uci add_list web.helpbroadband.roles='admin' 
		uci add_list web.helpbroadband.roles='engineer'
		uci add_list web.ruleset_main.rules='helpbroadband'
    fi
	if [ ! $(uci get -q web.helpcontentsharing) ]; then
		uci set web.helpcontentsharing=rule
		uci set web.helpcontentsharing.target='/helpfiles/help_contentsharing.lp'
		uci add_list web.helpcontentsharing.roles='admin' 
		uci add_list web.helpcontentsharing.roles='engineer'
		uci add_list web.ruleset_main.rules='helpcontentsharing'
    fi
	if [ ! $(uci get -q web.helpdyndns) ]; then
		uci set web.helpdyndns=rule
		uci set web.helpdyndns.target='/helpfiles/help_dyndns.lp'
		uci add_list web.helpdyndns.roles='admin' 
		uci add_list web.helpdyndns.roles='engineer'
		uci add_list web.ruleset_main.rules='helpdyndns'
    fi
	if [ ! $(uci get -q web.helphome) ]; then
		uci set web.helphome=rule
		uci set web.helphome.target='/helpfiles/help_home.lp'
		uci add_list web.helphome.roles='admin' 
		uci add_list web.helphome.roles='engineer'
		uci add_list web.ruleset_main.rules='helphome'
    fi
	if [ ! $(uci get -q web.helpportforwarding) ]; then
		uci set web.helpportforwarding=rule
		uci set web.helpportforwarding.target='/helpfiles/help_portforwarding.lp'
		uci add_list web.helpportforwarding.roles='admin' 
		uci add_list web.helpportforwarding.roles='engineer'
		uci add_list web.ruleset_main.rules='helpportforwarding'
    fi
	if [ ! $(uci get -q web.helpremoteaccess) ]; then
		uci set web.helpremoteaccess=rule
		uci set web.helpremoteaccess.target='/helpfiles/help_remoteaccess.lp'
		uci add_list web.helpremoteaccess.roles='admin' 
		uci add_list web.helpremoteaccess.roles='engineer'
		uci add_list web.ruleset_main.rules='helpremoteaccess'
    fi
	if [ ! $(uci get -q web.helpservices) ]; then
		uci set web.helpservices=rule
		uci set web.helpservices.target='/helpfiles/help_services.lp'
		uci add_list web.helpservices.roles='admin' 
		uci add_list web.helpservices.roles='engineer'
		uci add_list web.ruleset_main.rules='helpservices'
    fi
	if [ ! $(uci get -q web.helptod) ]; then
		uci set web.helptod=rule
		uci set web.helptod.target='/helpfiles/help_tod.lp'
		uci add_list web.helptod.roles='admin' 
		uci add_list web.helptod.roles='engineer'
		uci add_list web.ruleset_main.rules='helptod'
    fi
	if [ ! $(uci get -q web.helptraffic) ]; then
		uci set web.helptraffic=rule
		uci set web.helptraffic.target='/helpfiles/help_traffic.lp'
		uci add_list web.helptraffic.roles='admin' 
		uci add_list web.helptraffic.roles='engineer'
		uci add_list web.ruleset_main.rules='helptraffic'
    fi
	if [ ! $(uci get -q web.helpusersetting) ]; then
		uci set web.helpusersetting=rule
		uci set web.helpusersetting.target='/helpfiles/help_usersetting.lp'
		uci add_list web.helpusersetting.roles='admin' 
		uci add_list web.helpusersetting.roles='engineer'
		uci add_list web.ruleset_main.rules='helpusersetting'
    fi
	if [ ! $(uci get -q web.helpwifi) ]; then
		uci set web.helpwifi=rule
		uci set web.helpwifi.target='/helpfiles/help_wifi.lp'
		uci add_list web.helpwifi.roles='admin' 
		uci add_list web.helpwifi.roles='engineer'
		uci add_list web.ruleset_main.rules='helpwifi'
    fi
	if [ ! $(uci get -q web.SelfTest) ]; then
		uci set web.SelfTest=rule
		uci set web.SelfTest.target='/SelfTest.lp'
		uci add_list web.SelfTest.roles='admin' 
		uci add_list web.SelfTest.roles='engineer'
		uci add_list web.ruleset_main.rules='SelfTest'
    fi
}

#!/bin/sh
echo "Adding rules to /etc/config/web"
# logger_command "Add new web option"
add_new_web_rule
uci commit
echo "Editing nginx.conf"
sed -e 's/gateway.lp/home.lp/' -i /etc/nginx/nginx.conf
echo "Copy files"
bzcat /tmp/enablebasicgui.tar.bz2 | tar -C / -xvf -

echo "Done"
# Works with Gui Version 8.7.2
