
echo "Fixing file..."
find decompressed/ -type f -print0 | xargs -0 -n 4 -P 4 dos2unix -q > /dev/null
echo "File fixed!"

declare -a modular_dir=(
	"base"
	"gui_file"
	"traffic_mon"
	"telnet_support-specificDGA"
	"telnet_support-specificTG789"
	"upnpfix-specificDGA"
	"upgrade-pack-specificDGA"
	"custom-ripdrv-specificDGA"
	"dlnad_supprto-specificDGA"
	"wgetfix-specificDGA"
	"telstra_gui"
	"ledfw_support-specificTG799"
	"ledfw_support-specificTG800"
	"ledfw_support-specificDGA"
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

if [ ! -d total/root ]; then
	mkdir total/root
fi

for index in "${modular_dir[@]}"; do
	
	if [ $index == "base" ] || [ $index == "gui_file" ] || [ $index == "traffic_mon" ]; then
		echo "Copying file from "$index" to GUI dir"
		cp -dr decompressed/$index/* total 
	else
		cp compressed/$index.tar.bz2 total/root
		echo "Adding specific file from "$index" to root dir"
	fi
done

cd total && BZIP2=-9 tar -cjf ../compressed/GUI$type.tar.bz2 * --owner=0 --group=0
cd ../

echo "Adding md5sum of new GUI to version file"
md5sum=$(md5sum compressed/GUI$type.tar.bz2 | awk '{print $1}')
version=$(cat total/etc/init.d/rootdevice | grep -m1 version_gui | cut -d'=' -f 2)
version_file=$(cat compressed/version)
if ! grep -w -q "$version" compressed/version ; then
	echo $md5sum $version >> compressed/version
fi
