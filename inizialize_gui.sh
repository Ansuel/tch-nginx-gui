if [ $CI == "true" ]; then
  
	rootdevice_file="decompressed/base/etc/init.d/rootdevice"
	latest_version_link="https://raw.githubusercontent.com/Ansuel/gui-dev-build-auto/master/latest.version"
	version=$(curl -s $latest_version_link)
	
	echo "Increment version as this is an autobuild"
	
	major=$(echo $version | grep -Eo "^[0-9]+")
	dev_num=$(echo $version | sed -E s/[0-9]+\.[0-9]+\.//)
	minor=$(echo $version | sed  s#$major\.## | sed s#\\.$dev_num## )
	
	if [ $((dev_num + 1)) -gt 99 ]; then
		echo "dev_num greater than 99 increment minor"
		dev_num=0
		if [ $((minor + 1)) -gt 99 ]; then
			echo "minor greater than 99 increment minor"
			minor=0
			major=$((major + 1))
		else
			minor=$((minor + 1))
		fi
	else
		dev_num=$((dev_num + 1))
	fi

	new_version=$major.$minor.$dev_num
	
	echo "Detected version: "$version
	echo "New version to apply: "$new_version
	
	sed -i s#version_gui=TO_AUTO_COMPLETE#version_gui=$new_version# $rootdevice_file
fi


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

if [ ! -d total/tmp ]; then
	mkdir total/tmp
fi

for index in "${modular_dir[@]}"; do
	
	if [ $index == "base" ] || [ $index == "gui_file" ] || [ $index == "traffic_mon" ]; then
		echo "Copying file from "$index" to GUI dir"
		cp -dr decompressed/$index/* total 
	else
		cp modular/$index.tar.bz2 total/tmp
		echo "Adding specific file from "$index" to tmp virtual dir"
	fi
done

cd total && BZIP2=-9 tar -cjf ../compressed/GUI$type.tar.bz2 * --owner=0 --group=0
cd ../

if [ $CI == "true" ]; then
  
  git config --global user.name "CircleCI";
  git config --global user.email "CircleCI";
  
  ssh -o StrictHostKeyChecking=no git@github.com
  
  echo "Publishing dev build to auto repo...";
  git clone git@github.com:Ansuel/gui-dev-build-auto.git $HOME/gui-dev-build-auto/
  
  md5sum=$(md5sum compressed/GUI$type.tar.bz2 | awk '{print $1}')
  version=$(cat total/etc/init.d/rootdevice | grep -m1 version_gui | cut -d'=' -f 2)
  if ! grep -w -q "$version" $HOME/gui-dev-build-auto/version ; then
  	echo "Adding md5sum of new GUI to version file"
  	echo "Version: "$version" Md5sum: "$md5sum
  	echo $md5sum $version >> $HOME/gui-dev-build-auto/version
  else
  	echo "Md5sum already present. Overwriting..."
  	old_version_md5=$(grep -w "$version" $HOME/gui-dev-build-auto/version | awk '{print $1}')
  	sed -i "/$version/d" compressed/version
  	echo "Adding md5sum of new GUI to version file"
  	echo "Version: "$version" Old_Md5sum: "$old_version_md5
  	echo "Version: "$version" Md5sum: "$md5sum
  	echo $md5sum $version >> $HOME/gui-dev-build-auto/version
  fi

  cp compressed/GUI$type.tar.bz2 $HOME/gui-dev-build-auto/ -r;

  cd $HOME/gui-dev-build-auto/;
  
  echo $version > latest.version

  git add -A;
  git commit -a -m "Automatic dev build. Version: $version";
  git push origin master;

  echo "Done.";
fi
