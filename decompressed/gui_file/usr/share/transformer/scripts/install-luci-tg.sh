#!/bin/sh
filename="nutterpc-tg-luci-6f3cf6e"

curl -k -L https://github.com/nutterpc/tg-luci/blob/master/install.sh --output /tmp/install.sh
chmod +x /tmp/install.sh
/tmp/install.sh



