if [ $CI == "true" ]; then
	if [ -f ~/.dev ]; then
		type="_dev"
	elif [ -f ~/.stable ]; then
		stable_msg="STABLE"
	fi
fi
md5sum=$(md5sum compressed/GUI$type.tar.bz2 | awk '{print $1}')
version=$(cat total/etc/init.d/rootdevice | grep -m1 version_gui | cut -d'=' -f 2)
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
	if [ -f ~/.stable ]; then
		build_type_name="STABLE"
		echo $version > stable.version
	elif [ -f ~/.dev ]; then
		build_type_name="DEV"
	fi
	commit_link=https://github.com/Ansuel/tch-nginx-gui/commit/$CIRCLE_SHA1
fi

echo $version > latest.version

mkdir ~/gui_build/data

echo $version > ~/gui_build/data/version
echo $build_type_name > ~/gui_build/data/type

git add -A;
git commit -a -m "[$build_type_name] Version: $version Commit: $commit_link";
git push origin master;

echo "Done.";
