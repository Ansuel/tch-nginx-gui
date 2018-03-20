#!/bin/sh

wget=/usr/bin/wget
bzcat=/usr/bin/bzcat
tar=/bin/tar

# Check update_branch
if [ ! $(uci get -q env.var.update_branch) ] ||  [ $(uci get env.var.update_branch) == "stable" ]; then
	update_branch=""
else
	update_branch="_dev"
fi

WORKING_DIR="/tmp"
PERMANENT_STORE_DIR="/root"
TARGET_DIR="/"
FILE_NAME='GUI'$update_branch'.tar.bz2'
URL_BASE="http://repository.ilpuntotecnicoeadsl.com/files/Ansuel/AGTEF"
CHECKSUM_FILE="version"

if [ ! -f $WORKING_DIR/$FILE_NAME ]; then #Check if file exist as offline upload is now present
	# Enter /tmp folder
	if ! cd "$WORKING_DIR"; then
	echo "ERROR: can't access $WORKING_DIR" >&2
	exit 1
	fi
	
	# Clean older GUI archive if present
	for file in "$WORKING_DIR"/*; do
	rm -f "$FILE_NAME"*
	done
	
	# Download new GUI to /tmp
	if ! $wget $URL_BASE/$FILE_NAME; then
	echo "ERROR: can't find new GUI file" >&2
	exit 1
	fi
	
	# Check GUI hash
	if [ -f /tmp/$CHECKSUM_FILE ]; then
		rm $WORKING_DIR/$CHECKSUM_FILE
	fi
	wget $URL_BASE/$CHECKSUM_FILE
	if ! grep -q $(md5sum $WORKING_DIR/$FILE_NAME | awk '{print $1}') $WORKING_DIR/$CHECKSUM_FILE ; then
	echo "ERROR: file corrupted" >&2
	exit 1
	fi
fi

/etc/init.d/nginx stop

#clean old www dir

for dir in /www/* ; do
    if [ "$dir" = "/www/docroot" ]; then
		for subdir in /www/docroot/* ; do
			if [ "$subdir" = "/www/docroot/aria" ] || 
			   [ "$subdir" = "/www/docroot/transmission" ]; then
				continue
			else
				rm -rf "$subdir"
			fi
		done
    else
		rm -rf "$dir"
	fi
done

# Extract new GUI to /
bzcat "$WORKING_DIR/$FILE_NAME" | tar -C "$TARGET_DIR" -xvf -

# Restore blacklist contacts
blacklist_restore="http://blacklist.satellitar.it/repository/update_blacklist.sh"
fi [ $( uci get -q env.var.blacklist_app) ] && [ $( uci get env.var.blacklist_app) == "1" ]; then
	if wget $blacklist_restore ; then
		$WORKING_DIR/update_blacklist.sh
	fi
fi

#Copy GUI file to permanent dir
cp $WORKING_DIR/$FILE_NAME $PERMANENT_STORE_DIR
rm $WORKING_DIR/$FILE_NAME

# Run init.d script
/etc/init.d/rootdevice force