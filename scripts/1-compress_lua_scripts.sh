TYPE="$(cat $HOME/gui_build/data/type)"
if [ $TYPE == "DEV" ]; then
	exit 0
fi


pretranslated_string="--pretranslated: do not change this file"

minify_lua() {
	append_pretraslate=0
	if [ -n "$(grep $1 -e "$pretranslated_string")" ]; then
		append_pretraslate=1
	fi
	echo "Minying $file | Pretranslated:"$append_pretraslate
	luasrcdiet --maximum --quiet $1 -o $1.min
	if [ $append_pretraslate == 1 ]; then
		sed -i '1s/^/'"$pretranslated_string"'\n/' $1.min
		chmod $(stat -c "%a" $1) $1.min
	fi
}

for file in `find . -name "*.lua" -type f`; do
	minify_lua "$file" &
done

for file in `find . -name "*.lp" -type f`; do
	minify_lua "$file" &
done

for file in `find . -name "*.map" -type f`; do
	minify_lua "$file" &
done

wait

for file in `find . -name "*.lua" -o -name "*.lp" -o -name "*.map" -type f`; do
	if [ -f $file.min ]; then
		echo "Moving $( echo $file.min | sed 's|.*/||' ) to $( echo $file | sed 's|.*/||' )"
		rm $file
		mv $file.min $file
	fi
done


echo "Finished"