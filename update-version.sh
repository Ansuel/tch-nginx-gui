md5sum=$(md5sum compressed/GUI.tar.bz2 | awk '{print $1}')
version=$(cat total/etc/init.d/rootdevice | grep -m1 version_gui | cut -d'=' -f 2)
version_file=$(cat compressed/version)
if ! grep -w -q "$version" compressed/version ; then
	echo $md5sum $version >> compressed/version
fi
