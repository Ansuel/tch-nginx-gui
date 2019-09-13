if [ $CI == "true" ]; then
	TYPE="$(cat $HOME/gui_build/data/type)"
	if [ $TYPE == "PREVIEW" ]; then
		type="_preview"
	elif [ $TYPE == "DEV" ]; then
		type="_dev"
	fi
fi
md5sum=$(md5sum compressed/GUI$type.tar.bz2 | awk '{print $1}')
version="$(cat ~/gui_build/data/version)"
if ! grep -w -q "$version" $HOME/gui-dev-build-auto/version ; then
	echo "Adding md5sum of new GUI to version file"
	echo "Version: "$version" Md5sum: "$md5sum
	echo $md5sum $version >> $HOME/gui-dev-build-auto/version
else
	echo "Md5sum already present. Overwriting..."
	old_version_md5=$(grep -w "$version" $HOME/gui-dev-build-auto/version | awk '{print $1}')
	sed -i "/$version/d" $HOME/gui-dev-build-auto/version
	echo "Adding md5sum of new GUI to version file"
	echo "Version: "$version" Old_Md5sum: "$old_version_md5
	echo "Version: "$version" Md5sum: "$md5sum
	echo $md5sum $version >> $HOME/gui-dev-build-auto/version
fi

cp compressed/GUI$type.tar.bz2 $HOME/gui-dev-build-auto/ -r;

cd $HOME/gui-dev-build-auto/;

if [ $CI == "true" ]; then
	if [ ~/gui_build/data/type ]; then
		build_type_name=$(cat ~/gui_build/data/type)
		if [ $build_type_name == "STABLE" ]; then
			echo $version > stable.version
		elif  [ $build_type_name == "PREVIEW" ]; then
			echo $version > preview.version
		fi
	else
		build_type_name="DEV"
	fi
	commit_link=https://github.com/Ansuel/tch-nginx-gui/commit/$CIRCLE_SHA1
fi

echo $version > latest.version

git add -A;
git commit -a -m "[$build_type_name] Version: $version Commit: $commit_link";
git push origin master;

echo "Done.";
