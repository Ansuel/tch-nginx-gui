#!/bin/sh
curl -k -L https://raw.githubusercontent.com/nutterpc/tg-luci/master/install.sh --output /tmp/install.sh
chmod +x /tmp/install.sh
/tmp/install.sh
