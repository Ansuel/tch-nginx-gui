#!/bin/sh
if [ -d /www/telstra-snippets ]; then
	rm -r /www/telstra-snippets
	rm /www/gateway-snippets/telstra-gui.lp
	rm /www/docroot/telstra-gui.lp
	rm -r /www/docroot/telstra-modals
	rm -r /www/docroot/telstra-helpfiles
	rm -r /www/docroot/img/telstra
	rm /www/docroot/js/main-telstra-min.js
	rm /www/docroot/css/gw-telstra.css/gw-telstra.css
	/etc/init.d/nginx restart
fi

############TRANSFORMER UTILITY##################
set_transformer() {
	cmd="require('datamodel').set('"$1"','"$2"')"
	lua -e "$cmd"
}
#################################################

set_transformer "rpc.system.modgui.scriptRequest.state" "Complete"