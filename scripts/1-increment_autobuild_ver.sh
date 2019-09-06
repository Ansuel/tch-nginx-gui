last_log="$(cat $HOME/gui_build/data/last_log)"

if [ "$(echo "$last_log" | grep -o "\[[0-9]\+\.[0-9]\+\.[0-9]\+\]" | tr -d [ | tr -d ])" ]; then
	ver="$(echo "$last_log" | grep -o "\[[0-9]\+\.[0-9]\+\.[0-9]\+\]" | tr -d [ | tr -d ])"
	echo "Detected manual version: "$ver
else
	latest_version_link="https://raw.githubusercontent.com/Ansuel/gui-dev-build-auto/master/latest.version"
	cur_ver=$(curl -s $latest_version_link)
	
	if [ -f $HOME/gui-dev-build-auto/latest.version ]; then
		echo "Detected cached latest.version file... Checking it..."
		cached_version=$(cat $HOME/gui-dev-build-auto/latest.version | awk ' { print $1 } ' )
		echo "Cached version detected: $cached_version"
		echo "Remote version detected: $version"
		rm $HOME/gui-dev-build-auto/latest.version
		seconds=0
		if [ $cached_version == $version ]; then
			echo "Same version detected..."
		fi
		while [ $cached_version == $version ]; do
			if [[ seconds -gt 120 ]]; then 
				echo "Race-condition dectedted... Continuing anyway..."
				break
			fi
			seconds=$[$seconds +1]
			echo -ne 'Waiting new version to publish for '$seconds' seconds \r'
			version=$(curl -s $latest_version_link)
			sleep 1
		done
	fi
	
	echo "Increment version as this is an autobuild"
	
	major=$(echo $cur_ver | grep -Eo "^[0-9]+")
	dev_num=$(echo $cur_ver | sed -E s/[0-9]+\.[0-9]+\.//)
	minor=$(echo $cur_ver | sed  s#$major\.## | sed s#\\.$dev_num## )
	
	if [ $((dev_num + 1)) -gt 99 ]; then
		echo "dev_num greater than 99 increment minor"
		dev_num=0
		if [ $((minor + 1)) -gt 99 ]; then
			echo "minor greater than 99 increment minor"
			minor=0
			major=$((major + 1))
		else
			minor=$((minor + 1))
		fi
	else
		dev_num=$((dev_num + 1))
	fi
	
	ver=$major.$minor.$dev_num
	
	echo "Detected version: "$cur_ver
	echo "New version to apply: "$ver
fi

if [ ! -d  $HOME/gui_build/data ]; then
	mkdir $HOME/gui_build/data
fi

echo $ver > $HOME/gui_build/data/version
