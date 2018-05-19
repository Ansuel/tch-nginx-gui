wanmode=$(uci get -q network.config.wan_mode)
connectivity="yes"
if ping -q -c 1 -W 1 8.8.8.8 >/dev/null; then
  connectivity="yes"
else
  connectivity="no"
fi
base_dir=https://repository.ilpuntotecnico.com/files/Ansuel/AGTEF

if [ "$wanmode" != "bridge" ] && [ $connectivity == "yes" ]; then
	if [ ! $(uci get -q env.var.update_branch) ] ||  [ $(uci get env.var.update_branch) == "stable" ]; then
		update_branch=""
	else
		update_branch="_dev"
	fi
	newer_stable=0
	remote_link=$base_dir'/GUI'$update_branch'.tar.bz2'
	version_link=$base_dir'/version'
	online_md5=$(curl -k -s $remote_link | md5sum | awk '{print $1}')
	local_md5=$(uci get env.var.gui_hash)
	version_file=$(curl -k -s $version_link)
	
	new_version=$(echo "$version_file" | grep $online_md5 | awk '{print $2}' )
	
	if [ "$new_version" != "" ] ; then #cool way to test if we have internet connection
		if [ $update_branch == "_dev" ]; then
			stable_link=$base_dir'/GUI.tar.bz2'
			stable_md5=$(curl -k -s $stable_link | md5sum | awk '{print $1}')
			stable_version=$(echo "$version_file" | grep $stable_md5 | awk '{print $2}' )
			if [ $( echo $stable_version | sed -e 's/\.//g') -gt $( echo $new_version | sed -e 's/\.//g') ]; then
				new_version=$stable_version" STABLE"
			fi
			if [ $local_md5 != $stable_md5 ]; then
				newer_stable=1
			fi
		fi
		
		if [ "$online_md5" != "$local_md5" ] || [ $newer_stable == 1 ]; then
			uci set env.var.outdated_ver=1
			uci set env.var.new_ver="$new_version"
		else
			uci set env.var.outdated_ver=0
			uci set env.var.new_ver="Unknown"
		fi
	fi
	
	uci commit
	
	/etc/init.d/transformer reload
fi
