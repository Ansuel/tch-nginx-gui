
echo "Fixing file..."

nfile=0

check_file_ending() {
	for file in $1/*; do
		if [ -d $file ]; then
			check_file_ending $file
		else
			if [ -f $file ]; then
				nfile=$[$nfile +1]
				echo -ne 'File scanned: '$nfile'\r'
				if [ $( dos2unix -ic $file ) ]; then
					dos2unix $file
					echo "Detected bad line-ending here: $file"
				fi
			fi
		fi
	done
	
}

check_file_ending decompressed
echo ""
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

mkdir tar_tmp

for index in "${modular_dir[@]}"; do
	
	if [ -f modular/$index.tar.bz2 ]; then
		old_md5=$(md5sum modular/$index.tar.bz2 | awk '{print $1}')
	fi
	
	cd decompressed/$index
	BZIP2=-9 tar -cjf ../../tar_tmp/$index.tar.bz2 * --owner=0 --group=0
	cd ../../
	
	new_md5=$(md5sum tar_tmp/$index.tar.bz2 | awk '{print $1}')
	if [ -z "$old_md5" ] || [ "$old_md5" != "$new_md5" ]; then
		echo "Changes detected in modular package $index, updating..."
		cp tar_tmp/$index.tar.bz2 modular/
	fi
done

rm -r tar_tmp

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
		cp modular/$index.tar.bz2 total/root
		echo "Adding specific file from "$index" to root dir"
	fi
done

cd total && BZIP2=-9 tar -cjf ../compressed/GUI$type.tar.bz2 * --owner=0 --group=0
cd ../

md5sum=$(md5sum compressed/GUI$type.tar.bz2 | awk '{print $1}')
version=$(cat total/etc/init.d/rootdevice | grep -m1 version_gui | cut -d'=' -f 2)
version_file=$(cat compressed/version)
if ! grep -w -q "$version" compressed/version ; then
	echo "Adding md5sum of new GUI to version file"
	echo "Version: "$version" Md5sum: "$md5sum
	echo $md5sum $version >> compressed/version
else
	echo "Md5sum already present. Overwriting..."
	old_version_md5=$(grep -w "$version" compressed/version | awk '{print $1}')
	sed -i "/$version/d" compressed/version
	echo "Adding md5sum of new GUI to version file"
	echo "Version: "$version" Old_Md5sum: "$old_version_md5
	echo "Version: "$version" Md5sum: "$md5sum
	echo $md5sum $version >> compressed/version
fi
