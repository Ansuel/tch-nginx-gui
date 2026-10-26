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