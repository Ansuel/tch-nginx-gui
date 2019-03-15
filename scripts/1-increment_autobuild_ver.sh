last_log="$(git log --oneline -n 1)"
rootdevice_file="decompressed/base/etc/init.d/rootdevice"

if [ "$(echo "$last_log" | grep -o "\[[0-9]\+\.[0-9]\+\.[0-9]\+\]" | tr -d [ | tr -d ])" ]; then
	manual_ver="$(echo "$last_log" | grep -o "\[[0-9]\+\.[0-9]\+\.[0-9]\+\]" | tr -d [ | tr -d ])"
	echo "Detected manual version: "$manual_ver
	sed -i s#version_gui=TO_AUTO_COMPLETE#version_gui=$manual_ver# $rootdevice_file
else
	latest_version_link="https://raw.githubusercontent.com/Ansuel/gui-dev-build-auto/master/latest.version"
	version=$(curl -s $latest_version_link)
	
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
	
	major=$(echo $version | grep -Eo "^[0-9]+")
	dev_num=$(echo $version | sed -E s/[0-9]+\.[0-9]+\.//)
	minor=$(echo $version | sed  s#$major\.## | sed s#\\.$dev_num## )
	
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
	
	new_version=$major.$minor.$dev_num
	
	echo "Detected version: "$version
	echo "New version to apply: "$new_version
	
	sed -i s#version_gui=TO_AUTO_COMPLETE#version_gui=$new_version# $rootdevice_file
fi
