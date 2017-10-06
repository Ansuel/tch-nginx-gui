online_md5=$(curl -k -s http://repository.ilpuntotecnicoeadsl.com/files/Ansuel/AGTEF/GUI.tar.bz2 | md5sum | awk '{print $1}')
local_md5=$(uci get env.var.gui_hash)

if [ "$online_md5" == "$local_md5" ]; then
    uci set env.var.outdated_ver=0
else
    uci set env.var.outdated_ver=1
fi
/etc/init.d/transformer restart
