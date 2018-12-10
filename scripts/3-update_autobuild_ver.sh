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

echo $version > latest.version

git add -A;
git commit -a -m "Automatic dev build. Version: $version $stable_msg";
git push origin master;

echo "Done.";
