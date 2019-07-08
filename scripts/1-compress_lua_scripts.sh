TYPE="$(cat $HOME/gui_build/data/type)"
if [ $TYPE == "DEV" ]; then
	exit 0
fi

saved=0
pretranslated_string="--pretranslated: do not change this file"

minify_lua() {
	compressed=0
	append_pretraslate=0
	if [ -n "$(grep $1 -e "$pretranslated_string")" ]; then
		append_pretraslate=1
	fi
	echo "Minying $file | Pretranslated:"$append_pretraslate
	luasrcdiet --maximum --quiet $1 -o $1.min
	if [[ $? != 0 ]]; then echo "Minify error for $1";return; fi
	if [ $append_pretraslate == 1 ]; then
		sed -i '1s/^/'"$pretranslated_string"'\n/' $1.min
	fi
	perl -i -pe 's|(\ *\t*)\/\/(.*)\\\n?|$1\/\*$2 *\/\\\n|g' $1.min
	sed -i ':a;N;$!ba;s/\\\n\s*\t*//g' $1.min
	chmod $(stat -c "%a" $1) $1.min
	compressed=$(($(stat --printf="%s" $1)-$(stat --printf="%s" $1.min)))
	echo "File $1 minified for $compressed byte"
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
