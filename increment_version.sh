rootdevice_file="decompressed/base/etc/init.d/rootdevice"
	latest_version_link="https://raw.githubusercontent.com/Ansuel/gui-dev-build-auto/master/latest.version"
	version=$(curl -s $latest_version_link)
	
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

