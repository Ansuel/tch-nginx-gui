online_md5=$(curl -k -s http://repository.ilpuntotecnicoeadsl.com/files/Ansuel/AGTEF/GUI.tar.bz2 | md5sum | awk '{print $1}')
local_md5=$(uci get env.var.gui_hash)
version_file=$(curl -k -s http://repository.ilpuntotecnicoeadsl.com/files/Ansuel/AGTEF/version)

new_version=$(echo "$version_file" | grep $online_md5 | awk '{print $2}' )

if [ "$online_md5" == "$local_md5" ]; then
    uci set env.var.outdated_ver=0
	uci set env.var.new_ver="Unknown"
else
    uci set env.var.outdated_ver=1
	uci set env.var.new_ver=$new_version
fi

uci commit

/etc/init.d/transformer restart
