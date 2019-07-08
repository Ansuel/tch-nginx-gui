version="$(cat $HOME/gui_build/data/version)"
rootdevice_file="$HOME/gui_build/decompressed/base/etc/init.d/rootdevice"
echo "Setting version $version to rootdevice"
sed -i s#version_gui=TO_AUTO_COMPLETE#version_gui=$version# $rootdevice_file
	