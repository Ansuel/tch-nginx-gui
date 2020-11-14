#! /bin/sh

for type in css js lua lp map po; do
        cp -a data/"$type"_files/* decompressed/
        echo Applying files in "$type"_files
done