version="$(cat $HOME/gui_build/data/version)"
rootdevice_file="$HOME/gui_build/decompressed/base/etc/init.d/rootdevice"
cd $HOME/gui_build/
short_commit_hash=$(git log -1 --abbrev-commit --oneline | cut -d' ' -f1)
echo "Setting version $version to rootdevice"
sed -i s#version_gui=TO_AUTO_COMPLETE#version_gui=$version-$short_commit_hash# $rootdevice_file
	