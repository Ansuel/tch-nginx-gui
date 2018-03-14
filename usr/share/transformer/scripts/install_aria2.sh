opkg update
opkg install unzip aria2
wget https://github.com/mayswind/AriaNg-DailyBuild/archive/master.zip -P /tmp
unzip /tmp/master.zip -d /www/docroot/
rm /tmp/master.zip
mv /www/docroot/AriaNg-DailyBuild-master /www/docroot/aria