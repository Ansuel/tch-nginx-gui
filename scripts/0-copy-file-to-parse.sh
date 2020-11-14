#! /bin/sh

for type in css js lua lp map po; do
        mkdir data/"$type"_files
        echo Creating dir '$type'_files for files to be processed
        for file in `find . -name "*.$type" -type f`; do
            echo Copying $file
            cp -a --parents "$file" data/"$type"_files
        done
done
