#!/bin/sh
curl -k -L https://github.com/nutterpc/tg-luci/blob/master/install.sh --output /tmp/install.sh
chmod +x /tmp/install.sh
/tmp/install.sh
