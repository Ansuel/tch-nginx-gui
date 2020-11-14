TYPE="$(cat type)"
# if [ $TYPE == "DEV" ]; then
# 	exit 0
# fi

minify --recursive --verbose --match=\.*.js$ --type=js --output js_files/ js_files/

minify --recursive --verbose --match=\.*.css$ --type=css --output css_files/ css_files/

echo "Finished"