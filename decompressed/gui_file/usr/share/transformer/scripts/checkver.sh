wanmode=$(uci get -q network.config.wan_mode)
connectivity="yes"
if ping -q -c 1 -W 1 8.8.8.8 >/dev/null; then
  connectivity="yes"
else
  connectivity="no"
fi
if [ "$wanmode" != "bridge" ] && [ $connectivity == "yes" ]; then
	if [ ! $(uci get -q env.var.update_branch) ] ||  [ $(uci get env.var.update_branch) == "stable" ]; then
		update_branch=""
	else
		update_branch="_dev"
	fi
	remote_link='http://repository.ilpuntotecnicoeadsl.com/files/Ansuel/AGTEF/GUI'$update_branch'.tar.bz2'
	version_link='http://repository.ilpuntotecnicoeadsl.com/files/Ansuel/AGTEF/version'
	online_md5=$(curl -k -s $remote_link | md5sum | awk '{print $1}')
	local_md5=$(uci get env.var.gui_hash)
	version_file=$(curl -k -s $version_link)
	
	new_version=$(echo "$version_file" | grep $online_md5 | awk '{print $2}' )
	
	if [ "$new_version" != "" ] ; then #cool way to test if we have internet connection
		if [ "$online_md5" == "$local_md5" ]; then
			uci set env.var.outdated_ver=0
			uci set env.var.new_ver="Unknown"
		else
			uci set env.var.outdated_ver=1
			uci set env.var.new_ver=$new_version
		fi
	fi
	
	uci commit
	
	/etc/init.d/transformer reload
fi
