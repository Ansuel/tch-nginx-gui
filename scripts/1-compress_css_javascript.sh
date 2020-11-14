TYPE="$(cat $HOME/gui_build/data/type)"
# if [ $TYPE == "DEV" ]; then
# 	exit 0
# fi

minify --recursive --verbose --match=\.*.js$ --type=js --output decompressed/ decompressed/

minify --recursive --verbose --match=\.*.css$ --type=css --output decompressed/ decompressed/

echo "Finished"