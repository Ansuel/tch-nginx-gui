if [ ! $(uci get -q env.var.update_branch) ] ||  [ $(uci get env.var.update_branch) == "stable" ]; then
	update_branch=""
else
	update_branch="_dev"
fi
remote_file='http://repository.ilpuntotecnicoeadsl.com/files/Ansuel/AGTEF/GUI'$update_branch'.tar.bz2'
version_file='http://repository.ilpuntotecnicoeadsl.com/files/Ansuel/AGTEF/version'
online_md5=$(curl -k -s $remote_file | md5sum | awk '{print $1}')
local_md5=$(uci get env.var.gui_hash)
version_file=$(curl -k -s $version_file)

new_version=$(echo "$version_file" | grep $online_md5 | awk '{print $2}' )

if version_file ; then #cool way to test if we have internet connection
	if [ "$online_md5" == "$local_md5" ]; then
		uci set env.var.outdated_ver=0
		uci set env.var.new_ver="Unknown"
	else
		uci set env.var.outdated_ver=1
		uci set env.var.new_ver=$new_version
	fi
fi

uci commit

/etc/init.d/transformer restart
