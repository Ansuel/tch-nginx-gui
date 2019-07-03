last_log="$(git log --oneline -n 1)"

if [ ! -f  $HOME/gui_build/data ]; then
	mkdir $HOME/gui_build/data
fi

if [ "$( echo "$last_log" | grep "\[STABLE\]" )" ]; then
	echo "Detected STABLE build."
	echo STABLE > $HOME/gui_build/data/type
elif [ "$( echo "$last_log" | grep "\[PREVIEW\]" )" ]; then
	echo "Detected PREVIEW build."
	echo PREVIEW > $HOME/gui_build/data/type
else
	echo "Detected DEV build."
	echo DEV > $HOME/gui_build/data/type
fi
