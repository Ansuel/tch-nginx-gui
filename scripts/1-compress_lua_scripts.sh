#! /bin/sh

TYPE="$(cat type)"
if [ "$TYPE" != "STABLE" ] && [ "$TYPE" != "PREVIEW" ]; then
	exit 0
fi

pretranslated_string="--pretranslated: do not change this file"

minify_lua() {
	compressed=0
	append_pretraslate=0
	if grep -q "$1" -e "$pretranslated_string"; then
		append_pretraslate=1
	fi
	echo "Minying $file | Pretranslated:"$append_pretraslate
	
	if ! luasrcdiet --maximum --quiet "$1" -o "$1".min; then 
		echo "Minify error for $1"
		return
	fi

	if [ $append_pretraslate = 1 ]; then
		sed -i '1s/^/'"$pretranslated_string"'\n/' "$1".min
	fi
	perl -i -pe 's|(\ *\t*)\/\/(.*)\\\n?|"$1"\/\*$2 *\/\\\n|g' "$1".min
	sed -i ':a;N;$!ba;s/\\\n\s*\t*//g' "$1".min
	chmod "$(stat -c "%a" "$1")" "$1".min
	compressed=$(($(stat --printf="%s" "$1")-$(stat --printf="%s" "$1".min)))
	echo "File $1 minified for $compressed byte"
}

parse_files() {
	find "$1"_files ! -name "$(printf "*\n*")" -name "*.$1" -type f > "$1"_files_list
	while IFS= read -r file; do
		minify_lua "$file" &
		echo "Moving $( echo "$file".min | sed 's|.*/||' ) to $( echo "$file" | sed 's|.*/||' )"
		rm "$file"
		mv "$file".min "$file"
	done < "$1"_files_list
	rm "$1"_files_list
}

parse_files lua
parse_files lp
parse_files map

wait
