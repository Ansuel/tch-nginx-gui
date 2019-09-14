TYPE="$(cat $HOME/gui_build/data/type)"
if [ $TYPE == "DEV" ]; then
	exit 0
fi

minify_css() {
	curl -X POST -s --data-urlencode input@"$1" https://cssminifier.com/raw > $1.min
	chmod $(stat -c "%a" $1) $1.min
}

minify_js() {
	curl -X POST -s --data-urlencode input@"$1" https://javascript-minifier.com/raw > $1.min
	chmod $(stat -c "%a" $1) $1.min
}

for file in `find . -name "*.css" -type f`; do
    echo "Minying $file"
	minify_css "$file" &
done

for file in `find . -name "*.js" -type f`; do
    echo "Minying $file"
	minify_js "$file" &
done

wait

for file in `find . -name "*.css" -o -name "*.js" -type f`; do
	if [ -f $file.min ]; then
		echo "Moving $( echo $file.min | sed 's|.*/||' ) to $( echo $file | sed 's|.*/||' )"
		rm $file
		mv $file.min $file
	fi
done


echo "Finished"