#!/bin/sh

wget=/usr/bin/wget
bzcat=/usr/bin/bzcat
tar=/bin/tar

WORKING_DIR="/tmp"
TARGET_DIR="/"
FILE_NAME="GUI.tar.bz2"
URL_BASE="http://repository.ilpuntotecnicoeadsl.com/files/Ansuel/AGTEF"

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

# Extract new GUI to /
bzcat "$WORKING_DIR/$FILE_NAME" | tar -C "$TARGET_DIR" -xvf -

# Run init.d script
/etc/init.d/rootdevice force

# Cleanup leftovers
rm -f "$WORKING_DIR/$FILE_NAME"