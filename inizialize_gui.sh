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
	"ledfw_support-specificTG789"
	"ledfw_support-specificTG799"
	"ledfw_support-specificTG800"
	"ledfw_support-specificDGA"
)

if [ "$1" == "dev" ]; then
	echo "Dev build detected"
	type="_dev"
fi

if [ $CI == "true" ]; then
	if [ -f ~/.dev ]; then
		type="_dev"
	fi
fi

mkdir tar_tmp

for index in "${modular_dir[@]}"; do
	
	if [ $CI == "true" ] && [ -f $HOME/gui-dev-build-auto/modular/$index.tar.bz2 ]; then
		old_md5=$(md5sum <(bzcat $HOME/gui-dev-build-auto/modular/$index.tar.bz2) | awk '{print $1}')
	fi
	
	cd decompressed/$index
	
	#Creating md5sum file for status led eventing
	if [[ $index == "gui_file" ]]; then
		md5sum tmp/status-led-eventing.lua_new > tmp/status-led-eventing.md5sum
	fi
	
	#Creating md5sum for every ledfw_support modular dir
	if [[ $index == *"ledfw_support"* ]]; then
		md5sum etc/ledfw/stateMachines.lua > stateMachines.md5sum 
	fi
	
	BZIP2=-9 tar --mtime='2018-01-01' -cjf ../../tar_tmp/$index.tar.bz2 * --owner=0 --group=0
	cd ../../
	new_md5=$(md5sum <(bzcat tar_tmp/$index.tar.bz2) | awk '{print $1}')
	if [ -z "$old_md5" ] || [ "$old_md5" != "$new_md5" ]; then
		echo "Changes detected in modular package $index, updating..."
		cp tar_tmp/$index.tar.bz2 $HOME/gui-dev-build-auto/modular/
	fi
done

rm -r tar_tmp

echo "Creating GUI dir"

if [ -d total ]; then
	rm -r total
fi

if [ ! -d compressed ]; then
	mkdir compressed
fi

mkdir total

if [ ! -d total/tmp ]; then
	mkdir total/tmp
	#This is needed as on installation this will overwrite permission of /tmp dir
	chmod 777 total/tmp
fi

for index in "${modular_dir[@]}"; do
	
	if [ $index == "base" ] || [ $index == "gui_file" ] || [ $index == "traffic_mon" ]; then
		echo "Copying file from "$index" to GUI dir"
		cp -dr decompressed/$index/* total 
	else
		cp $HOME/gui-dev-build-auto/modular/$index.tar.bz2 total/tmp
		echo "Adding specific file from "$index" to tmp virtual dir"
	fi
done

cd total && BZIP2=-9 tar -cjf ../compressed/GUI$type.tar.bz2 * --owner=0 --group=0
cd ../
