if [ -d /www/telstra-snippets ]; then
	rm -r /www/telstra-snippets
	rm /www/gateway-snippets/telstra-gui.lp
	rm /www/docroot/telstra-gui.lp
	rm -r /www/docroot/telstra-modals
	rm -r /www/docroot/telstra-helpfiles/
	rm /www/docroot/js/main-telstra-min.js
	rm /www/docroot/css/gw-telstra.css/gw-telstra.css
fi
