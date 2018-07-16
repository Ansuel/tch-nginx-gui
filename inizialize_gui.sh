declare -a modular_dir=(
	"base"
	"gui_file"
	"traffic_mon"
	"telnet_support-specificDGA"
	"upnpfix-specificDGA"
	"upgrade-pack-specificDGA"
	"custom-ripdrv-specificDGA"
	"dlnad_supprto-specificDGA"
)

if [ "$1" == "dev" ]; then
	echo "Dev build detected"
	type="_dev"
fi

for index in "${modular_dir[@]}"; do
	echo "Creating modular package $index"
	cd decompressed/$index
	BZIP2=-9 tar -cjf ../../compressed/$index.tar.bz2 * --owner=0 --group=0
	cd ../../
	cp compressed/$index.tar.bz2 modular/
done

echo "Creating GUI dir"
if [ -d total ]; then
	rm -r total
fi
mkdir total

echo "Copying file to GUI dir"
cp -dr decompressed/base/* total 
cp -dr decompressed/gui_file/* total 
cp -dr decompressed/traffic_mon/* total

echo "Adding specific file to root dir"

if [ ! -d total/root ]; then
	mkdir total/root
fi

cp compressed/telnet_support-specificDGA.tar.bz2 total/root
cp compressed/upnpfix-specificDGA.tar.bz2 total/root
cp compressed/upgrade-pack-specificDGA.tar.bz2 total/root 
cp compressed/custom-ripdrv-specificDGA.tar.bz2 total/root 
cp compressed/dlnad_supprto-specificDGA.tar.bz2 total/root

cd total && BZIP2=-9 tar -cjf ../compressed/GUI$type.tar.bz2 * --owner=0 --group=0
cd ../

echo "Adding md5sum of new GUI to version file"
md5sum=$(md5sum compressed/GUI$type.tar.bz2 | awk '{print $1}')
version=$(cat total/etc/init.d/rootdevice | grep -m1 version_gui | cut -d'=' -f 2)
version_file=$(cat compressed/version)
if ! grep -w -q "$version" compressed/version ; then
	echo $md5sum $version >> compressed/version
fi
